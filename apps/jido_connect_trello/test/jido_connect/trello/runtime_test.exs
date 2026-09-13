defmodule Jido.Connect.Trello.RuntimeState do
  use Agent

  def start_link(_opts),
    do: Agent.start_link(fn -> %{calls: [], mode: :normal, timeouts: []} end, name: __MODULE__)

  def calls, do: Agent.get(__MODULE__, &Enum.reverse(&1.calls))
  def timeouts, do: Agent.get(__MODULE__, &Enum.reverse(&1.timeouts))
  def mode, do: Agent.get(__MODULE__, & &1.mode)
  def mode(mode), do: Agent.update(__MODULE__, &%{&1 | mode: mode})
  def observer, do: Agent.get(__MODULE__, &Map.get(&1, :observer))
  def observer(pid), do: Agent.update(__MODULE__, &Map.put(&1, :observer, pid))
  def clear, do: Agent.update(__MODULE__, &%{&1 | calls: []})
  def record(call), do: Agent.update(__MODULE__, &%{&1 | calls: [call | &1.calls]})

  def record_timeout(timeout),
    do: Agent.update(__MODULE__, &%{&1 | timeouts: [timeout | &1.timeouts]})
end

defmodule Jido.Connect.Trello.TestMCPClient do
  @behaviour Jido.Connect.MCP.Client

  alias Jido.Connect.Trello.{Contract, RuntimeState}

  @workspace_id "60eeea2273ccd82f506b3977"
  @board_object_id "6a61045166570c8531dc86a7"
  @board_ari "ari:cloud:trello::board/workspace/#{@workspace_id}/#{@board_object_id}"
  @list_ari "ari:cloud:trello::list/workspace/#{@workspace_id}/6a6105e754955319253c46ef"
  @card_ari "ari:cloud:trello::card/workspace/#{@workspace_id}/6a6105ed8ec975fc53dd6721"

  def list_tools(endpoint_id, opts) do
    RuntimeState.record_timeout(Keyword.fetch!(opts, :timeout))
    RuntimeState.record({:list_tools, endpoint_id})

    tools =
      Enum.map(Contract.tool_schemas(), fn {name, schema} ->
        schema =
          case {RuntimeState.mode(), name} do
            {:schema_drift, "trelloWriteCard"} ->
              put_in(schema, ["properties", "cardId", "type"], "integer")

            {:compatible_schema, _name} ->
              schema
              |> Map.put("title", "Captured Trello #{name} input")
              |> put_in(
                ["properties", "compatibleOptionalField"],
                %{"type" => "string", "description" => "A provider-owned optional field."}
              )

            _other ->
              schema
          end

        %{"name" => name, "inputSchema" => schema}
      end)

    {:ok, %{"tools" => tools}}
  end

  def call_tool(endpoint_id, tool, arguments, opts) do
    RuntimeState.record_timeout(Keyword.fetch!(opts, :timeout))
    RuntimeState.record({:call_tool, endpoint_id, tool, arguments})

    case {RuntimeState.mode(), tool, arguments.action} do
      {:transport_error, _, _} ->
        {:error, %{reason: :transport}}

      {:block_write_error, "trelloWriteCard", "create"} ->
        send(RuntimeState.observer(), {:trello_write_started, self()})

        receive do
          :continue_trello_write ->
            {:error, %{reason: :transport}}
        end

      {:wrong_board, "trelloReadBoard", "get"} ->
        ok(Map.put(board(), "name", "Other board"))

      {_, "trelloReadBoard", "get"} ->
        ok(board())

      {_, "trelloReadList", "list_by_board"} ->
        ok(%{
          "lists" => [list()],
          "pageInfo" => %{"hasNextPage" => false, "endCursor" => nil}
        })

      {_, "trelloWriteCard", "create"} ->
        ok(card(arguments))

      {_, "trelloReadCard", "get"} ->
        ok(card(%{}))

      {_, "trelloReadCard", "list_by_board"} ->
        ok(%{
          "lists" => [%{"id" => @list_ari, "name" => "Doing", "cards" => [card(%{})]}],
          "hasNextPage" => false,
          "nextCursor" => nil
        })

      other ->
        raise "unexpected fake Trello call: #{inspect(other)}"
    end
  end

  defp ok(payload), do: {:ok, %{"structuredContent" => payload}}

  defp board do
    %{
      "id" => @board_ari,
      "objectId" => @board_object_id,
      "shortLink" => "Z4Htjzwu",
      "name" => "Decentra Finance",
      "url" => "https://trello.com/b/Z4Htjzwu/decentra-finance",
      "closed" => false
    }
  end

  defp list do
    %{
      "id" => @list_ari,
      "objectId" => "6a6105e754955319253c46ef",
      "name" => "Doing",
      "position" => 16_384
    }
  end

  defp card(arguments) do
    %{
      "id" => @card_ari,
      "objectId" => "6a6105ed8ec975fc53dd6721",
      "name" => Map.get(arguments, :name, "Card"),
      "description" => "",
      "url" => "https://trello.com/c/Abc123/card",
      "boardId" => @board_ari,
      "listId" => Map.get(arguments, :listId, @list_ari),
      "closed" => false,
      "complete" => false,
      "labels" => [],
      "checklists" => [],
      "due" => nil
    }
  end
end

defmodule Jido.Connect.Trello.RuntimeTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.MCP.EndpointLeaseManager
  alias Jido.Connect.Trello
  alias Jido.Connect.Trello.RuntimeState

  @workspace_id "60eeea2273ccd82f506b3977"
  @board_object_id "6a61045166570c8531dc86a7"
  @board_ari "ari:cloud:trello::board/workspace/#{@workspace_id}/#{@board_object_id}"
  @list_ari "ari:cloud:trello::list/workspace/#{@workspace_id}/6a6105e754955319253c46ef"
  @off_board_card_ari "ari:cloud:trello::card/workspace/#{@workspace_id}/aaaaaaaaaaaaaaaaaaaaaaaa"

  setup do
    {:ok, _state} = start_supervised(RuntimeState)
    {context, lease} = context_and_lease()
    on_exit(fn -> EndpointLeaseManager.force_stop(context.connection) end)
    %{context: context, lease: lease}
  end

  test "generated board read forwards the host timeout", context do
    assert {:ok, %{kind: "workBoard", board: %{id: @board_ari}}} =
             Jido.Connect.Trello.Actions.GetBoard.run(%{}, %{
               integration_context: context.context,
               credential_lease: context.lease,
               request_timeout_ms: 5_000
             })

    internal = Jido.Connect.MCP.HostEndpoint.internal_id(context.context.connection)

    assert RuntimeState.calls() == [
             {:list_tools, internal},
             {:call_tool, internal, "trelloReadBoard",
              %{action: "get", boardId: "https://trello.com/b/Z4Htjzwu/decentra-finance"}}
           ]

    assert RuntimeState.timeouts() == [5_000, 5_000]
  end

  test "a host can set a shorter bounded MCP request timeout", context do
    assert {:ok, %{kind: "workBoard"}} =
             Connect.invoke(
               Trello,
               "trello.board.get",
               %{},
               runtime_opts(context) ++ [request_timeout_ms: 5_000]
             )

    assert RuntimeState.timeouts() == [5_000, 5_000]
  end

  test "confirmed card create verifies board and list, then sends one exact write", context do
    input = %{list_id: @list_ari, name: "Review access policy", position: "bottom"}

    assert {:ok, prepared} =
             Connect.prepare(
               Trello,
               "trello.card.create",
               input,
               runtime_opts(context) ++ [binding_ref: "trello-binding"]
             )

    assert prepared.confirmation_required?
    assert prepared.preview["description_characters"] == 0
    assert RuntimeState.calls() == []

    assert {:ok, %{kind: "workCardEffect", effect: "create"}} =
             Connect.commit(
               Trello,
               prepared,
               input,
               runtime_opts(context) ++
                 [
                   request_timeout_ms: 5_000,
                   binding_ref: "trello-binding",
                   execution_authorization: %{plan_id: prepared.id},
                   authorization_validator: fn evidence, plan, _context ->
                     evidence.plan_id == plan.id
                   end
                 ]
             )

    writes =
      RuntimeState.calls()
      |> Enum.filter(fn
        {:call_tool, _, "trelloWriteCard", _} -> true
        _ -> false
      end)

    assert [{:call_tool, _endpoint, "trelloWriteCard", arguments}] = writes

    assert arguments == %{
             action: "create",
             listId: @list_ari,
             name: "Review access policy",
             pos: "bottom"
           }

    assert RuntimeState.timeouts() != []
    assert Enum.uniq(RuntimeState.timeouts()) == [5_000]
  end

  test "board mismatch and schema drift fail before the remote write", context do
    RuntimeState.mode(:wrong_board)
    input = %{list_id: @list_ari, name: "Card"}

    assert {:ok, prepared} =
             Connect.prepare(
               Trello,
               "trello.card.create",
               input,
               runtime_opts(context) ++ [binding_ref: "trello-binding"]
             )

    assert {:error, %Connect.Error.AuthError{reason: :trello_board_mismatch}} =
             commit(prepared, input, context)

    refute Enum.any?(RuntimeState.calls(), fn
             {:call_tool, _, "trelloWriteCard", _} -> true
             _ -> false
           end)

    RuntimeState.clear()
    RuntimeState.mode(:schema_drift)

    assert {:ok, schema_prepared} =
             Connect.prepare(
               Trello,
               "trello.card.create",
               input,
               runtime_opts(context) ++ [binding_ref: "trello-binding"]
             )

    assert {:error, %Connect.Error.ProviderError{reason: :mcp_tool_schema_changed}} =
             commit(schema_prepared, input, context)

    refute Enum.any?(RuntimeState.calls(), fn
             {:call_tool, _, "trelloWriteCard", _} -> true
             _ -> false
           end)
  end

  test "card get proves board membership before the direct lookup", context do
    assert {:error, %Connect.Error.AuthError{reason: :trello_card_board_mismatch}} =
             Connect.invoke(
               Trello,
               "trello.card.get",
               %{id: @off_board_card_ari},
               runtime_opts(context)
             )

    assert Enum.any?(RuntimeState.calls(), fn
             {:call_tool, _endpoint, "trelloReadCard",
              %{action: "list_by_board", boardIdOrUrl: @board_ari}} ->
               true

             _other ->
               false
           end)

    refute Enum.any?(RuntimeState.calls(), fn
             {:call_tool, _endpoint, "trelloReadCard",
              %{action: "get", cardIdOrUrl: @off_board_card_ari}} ->
               true

             _other ->
               false
           end)
  end

  test "provider errors are Trello-owned and secret-safe", context do
    RuntimeState.mode(:transport_error)

    assert {:error, %Connect.Error.ProviderError{provider: :trello} = error} =
             Connect.invoke(Trello, "trello.board.get", %{}, runtime_opts(context))

    rendered = inspect(error) <> inspect(Connect.Error.to_map(error))
    refute rendered =~ "secret-token"
  end

  test "compatible live schema extensions are accepted and pinned to the endpoint generation",
       context do
    RuntimeState.mode(:compatible_schema)

    assert {:ok, %{kind: "workBoard"}} =
             Connect.invoke(Trello, "trello.board.get", %{}, runtime_opts(context))

    RuntimeState.mode(:normal)

    assert {:error, %Connect.Error.ProviderError{reason: :mcp_tool_schema_changed}} =
             Connect.invoke(Trello, "trello.board.get", %{}, runtime_opts(context))
  end

  test "credential rotation creates a new endpoint generation", context do
    assert {:ok, _board} =
             Connect.invoke(Trello, "trello.board.get", %{}, runtime_opts(context))

    [first] = EndpointLeaseManager.ownership(context.context.connection)
    assert first.credential_version == 1

    rotated_lease = lease(context.context.connection, 2, "trello-runtime-rotated")
    rotated_context = %{context | lease: rotated_lease}

    assert {:ok, _board} =
             Connect.invoke(Trello, "trello.board.get", %{}, runtime_opts(rotated_context))

    [second] = EndpointLeaseManager.ownership(context.context.connection)
    assert second.credential_version == 2
    assert second.generation == first.generation + 1
    refute second.endpoint_id == first.endpoint_id
  end

  test "connection removal revokes the lease and removes the endpoint", context do
    assert {:ok, _board} =
             Connect.invoke(Trello, "trello.board.get", %{}, runtime_opts(context))

    [ownership] = EndpointLeaseManager.ownership(context.context.connection)
    assert ownership.status == :active

    assert :ok = EndpointLeaseManager.connection_removed(context.context.connection)
    assert EndpointLeaseManager.ownership(context.context.connection) == []

    assert {:error, %Connect.Error.AuthError{reason: :mcp_endpoint_lease_stale}} =
             Connect.invoke(Trello, "trello.board.get", %{}, runtime_opts(context))
  end

  test "a revoked in-flight write is uncertain and is never retried", context do
    input = %{list_id: @list_ari, name: "Review access policy"}

    assert {:ok, prepared} =
             Connect.prepare(
               Trello,
               "trello.card.create",
               input,
               runtime_opts(context) ++ [binding_ref: "trello-binding"]
             )

    RuntimeState.mode(:block_write_error)
    RuntimeState.observer(self())

    task = Task.async(fn -> commit(prepared, input, context) end)
    assert_receive {:trello_write_started, write_pid}, 1_000
    assert :ok = EndpointLeaseManager.revoke(context.context.connection)
    send(write_pid, :continue_trello_write)

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :trello,
              reason: :mcp_write_uncertain,
              delivery: :sent_outcome_unknown,
              mutation?: true,
              provider_idempotency?: false
            } = error} = Task.await(task)

    assert Connect.Error.retry_guidance(error) == :do_not_retry

    writes =
      RuntimeState.calls()
      |> Enum.filter(fn
        {:call_tool, _, "trelloWriteCard", _} -> true
        _other -> false
      end)

    assert length(writes) == 1
  end

  defp commit(prepared, input, context) do
    Connect.commit(
      Trello,
      prepared,
      input,
      runtime_opts(context) ++
        [
          binding_ref: "trello-binding",
          execution_authorization: %{plan_id: prepared.id},
          authorization_validator: fn evidence, plan, _context -> evidence.plan_id == plan.id end
        ]
    )
  end

  defp runtime_opts(context) do
    [
      context: context.context,
      credential_lease: context.lease
    ]
  end

  defp context_and_lease(connection_id \\ nil) do
    connection_id = connection_id || "trello-runtime-#{System.unique_integer([:positive])}"

    connection =
      Connect.Connection.new!(%{
        id: connection_id,
        provider: :trello,
        profile: :oauth_user,
        tenant_id: "tenant-1",
        owner_type: :user,
        owner_id: "user-1",
        subject: %{id: "trello-user-1"},
        status: :connected,
        scopes: ["trello:read", "trello:write", "trello:search"],
        metadata: %{
          mcp_endpoint_id: "trello",
          connection_revision: 1,
          board_name: "Decentra Finance",
          board_url: "https://trello.com/b/Z4Htjzwu/decentra-finance",
          board_ari: @board_ari,
          board_object_id: @board_object_id,
          board_short_id: "Z4Htjzwu",
          workspace_object_id: @workspace_id
        }
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant-1",
        actor: %{id: "agent-1", type: :agent},
        connection: connection
      })

    lease = lease(connection, 1, "trello-runtime-test")

    {context, lease}
  end

  defp lease(connection, credential_version, client_name) do
    Connect.CredentialLease.from_connection!(
      connection,
      %{
        mcp_client_module: Jido.Connect.Trello.TestMCPClient,
        mcp_client_ref: Jido.Connect.MCP.HostEndpoint.internal_id(connection),
        mcp_endpoint: %{
          transport:
            {:streamable_http,
             [
               url: "https://mcp.trello.com/v1",
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
