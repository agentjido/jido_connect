defmodule Jido.Connect.X.RuntimeState do
  use Agent

  def start_link(_opts),
    do: Agent.start_link(fn -> %{calls: [], mode: :normal, timeouts: []} end, name: __MODULE__)

  def calls, do: Agent.get(__MODULE__, &Enum.reverse(&1.calls))
  def timeouts, do: Agent.get(__MODULE__, &Enum.reverse(&1.timeouts))
  def mode, do: Agent.get(__MODULE__, & &1.mode)
  def mode(mode), do: Agent.update(__MODULE__, &%{&1 | mode: mode})
  def observer, do: Agent.get(__MODULE__, &Map.get(&1, :observer))
  def observer(pid), do: Agent.update(__MODULE__, &Map.put(&1, :observer, pid))
  def record(call), do: Agent.update(__MODULE__, &%{&1 | calls: [call | &1.calls]})

  def record_timeout(timeout),
    do: Agent.update(__MODULE__, &%{&1 | timeouts: [timeout | &1.timeouts]})
end

defmodule Jido.Connect.X.TestMCPClient do
  alias Jido.Connect.X.{Contract, RuntimeState}

  def list_tools(endpoint_id, opts) do
    RuntimeState.record_timeout(Keyword.fetch!(opts, :timeout))
    RuntimeState.record({:list_tools, endpoint_id})

    tools =
      Enum.map(Contract.tool_schemas(), fn {name, schema} ->
        schema =
          case {RuntimeState.mode(), name} do
            {:schema_drift, "get_users_bookmarks"} ->
              put_in(schema, ["properties", "id", "type"], "integer")

            {:compatible_schema, _name} ->
              schema
              |> Map.put("description", "Captured X #{name} input")
              |> put_in(
                ["properties", "provider_optional_field"],
                %{"type" => "string", "description" => "Provider-owned optional input."}
              )

            _other ->
              schema
          end

        %{"name" => name, "inputSchema" => schema}
      end)

    {:ok, %{status: :ok, data: %{"tools" => tools}}}
  end

  def call_tool(endpoint_id, tool, arguments, opts) do
    RuntimeState.record_timeout(Keyword.fetch!(opts, :timeout))
    RuntimeState.record({:call_tool, endpoint_id, tool, arguments})

    case {RuntimeState.mode(), tool} do
      {:transport_error, _tool} ->
        {:error, %{type: :transport, message: "Bearer secret-x-token failed"}}

      {:remote_error, "get_users_me"} ->
        {:ok,
         %{
           status: :ok,
           data: %{
             "isError" => true,
             "content" => [%{"type" => "text", "text" => "secret remote error"}]
           }
         }}

      {:wrong_username, "get_users_me"} ->
        ok(account("other_user"))

      {:block_identity, "get_users_me"} ->
        send(RuntimeState.observer(), {:x_identity_started, self()})

        receive do
          :continue_x_identity -> ok(account("mike_hostetler"))
        end

      {_mode, "get_users_me"} ->
        ok(account("Mike_Hostetler"))

      {_mode, "get_users_bookmarks"} ->
        if arguments.id != "x-user-1", do: raise("account id was not injected")

        text_ok(%{
          "data" => [post("bookmark-1", "A saved post")],
          "meta" => %{"next_token" => "bookmark-next"}
        })

      {_mode, "get_users_posts"} ->
        if arguments.id != "x-user-1", do: raise("account id was not injected")

        ok(%{
          "data" => [post("post-1", "A current post")],
          "meta" => %{"next_token" => "post-next"}
        })

      other ->
        raise "unexpected fake X call: #{inspect(other)}"
    end
  end

  defp ok(payload), do: {:ok, %{status: :ok, data: %{"structuredContent" => payload}}}

  defp text_ok(payload) do
    {:ok,
     %{
       status: :ok,
       data: %{"content" => [%{"type" => "text", "text" => Jason.encode!(payload)}]}
     }}
  end

  defp account(username) do
    %{"data" => %{"id" => "x-user-1", "username" => username, "name" => "Mike"}}
  end

  defp post(id, text) do
    %{
      "id" => id,
      "text" => text,
      "author_id" => "author-1",
      "created_at" => "2026-08-19T12:00:00Z"
    }
  end
end

defmodule Jido.Connect.X.RuntimeTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.MCP.EndpointLeaseManager
  alias Jido.Connect.X
  alias Jido.Connect.X.RuntimeState

  setup do
    {:ok, _state} = start_supervised(RuntimeState)
    {context, lease} = context_and_lease()
    on_exit(fn -> EndpointLeaseManager.force_stop(context.connection) end)
    %{context: context, lease: lease}
  end

  test "gets identity first and injects its account id into exact list calls", context do
    opts = runtime_opts(context)

    assert {:ok, %{kind: "social_account", id: "x-user-1"}} =
             Connect.invoke(X, "x.account.get", %{}, opts)

    assert {:ok,
            %{
              kind: "social_bookmarks",
              account: %{id: "x-user-1", username: "Mike_Hostetler"},
              count: 1,
              limit: 25,
              next_cursor: "bookmark-next"
            }} =
             Connect.invoke(
               X,
               "x.bookmark.list",
               %{max_results: 25, pagination_token: "next"},
               opts
             )

    assert {:ok, %{kind: "social_posts", next_cursor: "post-next"}} =
             Connect.invoke(X, "x.post.list", %{}, opts)

    internal = Jido.Connect.MCP.HostEndpoint.internal_id(context.context.connection)

    assert RuntimeState.calls() == [
             {:list_tools, internal},
             {:call_tool, internal, "get_users_me", %{}},
             {:list_tools, internal},
             {:call_tool, internal, "get_users_me", %{}},
             {:list_tools, internal},
             {:call_tool, internal, "get_users_bookmarks",
              %{id: "x-user-1", max_results: 25, pagination_token: "next"}},
             {:list_tools, internal},
             {:call_tool, internal, "get_users_me", %{}},
             {:list_tools, internal},
             {:call_tool, internal, "get_users_posts", %{id: "x-user-1", max_results: 5}}
           ]

    assert RuntimeState.timeouts() != []
    assert Enum.uniq(RuntimeState.timeouts()) == [30_000]
  end

  test "a host can set a shorter bounded MCP request timeout", context do
    assert {:ok, %{kind: "social_account"}} =
             Connect.invoke(
               X,
               "x.account.get",
               %{},
               runtime_opts(context) ++ [request_timeout_ms: 5_000]
             )

    assert RuntimeState.timeouts() == [5_000, 5_000]
  end

  test "identity mismatch stops before bookmarks", context do
    RuntimeState.mode(:wrong_username)

    assert {:error, %Connect.Error.AuthError{reason: :x_account_mismatch}} =
             Connect.invoke(X, "x.bookmark.list", %{}, runtime_opts(context))

    refute Enum.any?(RuntimeState.calls(), fn
             {:call_tool, _, "get_users_bookmarks", _} -> true
             _other -> false
           end)
  end

  test "schema drift stops before the changed tool call", context do
    RuntimeState.mode(:schema_drift)

    assert {:error, %Connect.Error.ProviderError{reason: :mcp_tool_schema_changed}} =
             Connect.invoke(X, "x.bookmark.list", %{}, runtime_opts(context))

    refute Enum.any?(RuntimeState.calls(), fn
             {:call_tool, _, "get_users_bookmarks", _} -> true
             _other -> false
           end)
  end

  test "compatible live schema extensions are accepted and pinned to the endpoint generation",
       context do
    RuntimeState.mode(:compatible_schema)

    assert {:ok, %{kind: "social_account"}} =
             Connect.invoke(X, "x.account.get", %{}, runtime_opts(context))

    RuntimeState.mode(:normal)

    assert {:error, %Connect.Error.ProviderError{reason: :mcp_tool_schema_changed}} =
             Connect.invoke(X, "x.account.get", %{}, runtime_opts(context))
  end

  test "provider errors are X-owned and secret-safe", context do
    RuntimeState.mode(:transport_error)

    assert {:error, %Connect.Error.ProviderError{provider: :x} = error} =
             Connect.invoke(X, "x.account.get", %{}, runtime_opts(context))

    rendered = inspect(error) <> inspect(Connect.Error.to_map(error))
    refute rendered =~ "secret-x-token"

    RuntimeState.mode(:remote_error)

    assert {:error,
            %Connect.Error.ProviderError{provider: :x, reason: :remote_tool_error} = remote_error} =
             Connect.invoke(X, "x.account.get", %{}, runtime_opts(context))

    refute inspect(remote_error) <> inspect(Connect.Error.to_map(remote_error)) =~
             "secret remote error"
  end

  test "credential rotation creates a new endpoint generation", context do
    assert {:ok, _account} =
             Connect.invoke(X, "x.account.get", %{}, runtime_opts(context))

    [first] = EndpointLeaseManager.ownership(context.context.connection)
    assert first.credential_version == 1

    rotated_lease = lease(context.context.connection, 2, "x-runtime-rotated")
    rotated_context = %{context | lease: rotated_lease}

    assert {:ok, _account} =
             Connect.invoke(X, "x.account.get", %{}, runtime_opts(rotated_context))

    [second] = EndpointLeaseManager.ownership(context.context.connection)
    assert second.credential_version == 2
    assert second.generation == first.generation + 1
    refute second.endpoint_id == first.endpoint_id
  end

  test "revocation during identity fences the following read and does not retry", context do
    RuntimeState.mode(:block_identity)
    RuntimeState.observer(self())

    task =
      Task.async(fn ->
        Connect.invoke(X, "x.bookmark.list", %{}, runtime_opts(context))
      end)

    assert_receive {:x_identity_started, identity_pid}, 1_000
    assert :ok = EndpointLeaseManager.revoke(context.context.connection)
    send(identity_pid, :continue_x_identity)

    assert {:error, %Connect.Error.AuthError{reason: :mcp_endpoint_lease_stale}} =
             Task.await(task)

    identity_calls =
      Enum.count(RuntimeState.calls(), fn
        {:call_tool, _, "get_users_me", _} -> true
        _other -> false
      end)

    assert identity_calls == 1

    refute Enum.any?(RuntimeState.calls(), fn
             {:call_tool, _, "get_users_bookmarks", _} -> true
             _other -> false
           end)
  end

  test "connection removal revokes ownership and removes the endpoint", context do
    assert {:ok, _account} =
             Connect.invoke(X, "x.account.get", %{}, runtime_opts(context))

    [ownership] = EndpointLeaseManager.ownership(context.context.connection)
    assert {:ok, _endpoint} = Jido.MCP.ClientPool.fetch_endpoint(ownership.endpoint_id)

    assert :ok = EndpointLeaseManager.connection_removed(context.context.connection)
    assert EndpointLeaseManager.ownership(context.context.connection) == []
    assert {:error, :unknown_endpoint} = Jido.MCP.ClientPool.fetch_endpoint(ownership.endpoint_id)

    assert {:error, %Connect.Error.AuthError{reason: :mcp_endpoint_lease_stale}} =
             Connect.invoke(X, "x.account.get", %{}, runtime_opts(context))
  end

  defp runtime_opts(context) do
    [context: context.context, credential_lease: context.lease]
  end

  defp context_and_lease do
    connection =
      Connect.Connection.new!(%{
        id: "x-runtime-#{System.unique_integer([:positive])}",
        provider: :x,
        profile: :local_mcp,
        tenant_id: "tenant-1",
        owner_type: :user,
        owner_id: "user-1",
        subject: %{id: "x-user"},
        status: :connected,
        scopes: ["tweet.read", "users.read", "bookmark.read"],
        metadata: %{
          mcp_endpoint_id: "x",
          expected_username: "mike_hostetler",
          connection_revision: 1
        }
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant-1",
        actor: %{id: "agent-1", type: :agent},
        connection: connection
      })

    {context, lease(connection, 1, "x-runtime-test")}
  end

  defp lease(connection, credential_version, client_name) do
    Connect.CredentialLease.from_connection!(
      connection,
      %{
        mcp_client: Jido.Connect.X.TestMCPClient,
        mcp_endpoint: %{
          transport:
            {:streamable_http,
             [
               url: "http://127.0.0.1:8000/mcp",
               headers: [{"authorization", "Bearer credential-#{credential_version}"}]
             ]},
          client_info: %{name: client_name},
          client_options: []
        }
      },
      expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
      metadata: %{credential_version: credential_version}
    )
  end
end
