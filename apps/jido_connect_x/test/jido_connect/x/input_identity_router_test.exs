defmodule Jido.Connect.X.InputIdentityRouterTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{Connection, Context, CredentialLease, Error}
  alias Jido.Connect.X.{Contract, Identity, Input, Router}

  test "validates reviewed inputs and defaults" do
    assert {:ok, %{}} = Input.validate("x.account.get", %{})

    assert {:ok, %{max_results: 20, pagination_token: nil}} =
             Input.validate("x.bookmark.list", %{})

    assert {:ok, %{max_results: 100, pagination_token: "next-page"}} =
             Input.validate("x.bookmark.list", %{
               "max_results" => 100,
               "pagination_token" => "next-page"
             })

    assert {:ok, %{max_results: 5, pagination_token: nil}} =
             Input.validate("x.post.list", %{})
  end

  test "rejects bounds and all endpoint, tool, action, and account overrides" do
    invalid = [
      {"x.bookmark.list", %{max_results: 0}},
      {"x.bookmark.list", %{max_results: 101}},
      {"x.post.list", %{max_results: 4}},
      {"x.post.list", %{max_results: 101}},
      {"x.post.list", %{pagination_token: ""}},
      {"x.post.list", %{pagination_token: String.duplicate("x", 2_049)}},
      {"x.account.get", %{endpoint_id: "other"}},
      {"x.account.get", %{endpoint: "other"}},
      {"x.account.get", %{tool_name: "delete_users_bookmark"}},
      {"x.account.get", %{tool: "delete_users_bookmark"}},
      {"x.account.get", %{action: "write"}},
      {"x.bookmark.list", %{account: %{id: "other"}}},
      {"x.bookmark.list", %{account_id: "other"}},
      {"x.bookmark.list", %{user_id: "other"}},
      {"x.bookmark.list", %{id: "other"}},
      {"x.post.list", %{username: "other"}},
      {"x.post.list", %{expected_username: "other"}}
    ]

    for {action, input} <- invalid do
      assert {:error, %Error.ValidationError{reason: :invalid_x_input}} =
               Input.validate(action, input)
    end
  end

  test "normalizes strict X usernames before exact comparison" do
    assert {:ok, "mike_hostetler"} = Identity.normalize_username("Mike_Hostetler")
    identity = %Identity{expected_username: "mike_hostetler"}
    assert Identity.matches_authenticated_username?(identity, "Mike_Hostetler")
    refute Identity.matches_authenticated_username?(identity, "other_user")

    for username <- ["", "@mike", "has-hyphen", String.duplicate("x", 16), " user"] do
      assert {:error, %Error.AuthError{reason: :invalid_x_username}} =
               Identity.normalize_username(username)
    end
  end

  test "requires the X connection, expected username, and exact local endpoint" do
    runtime = runtime()

    assert {:ok, %Identity{expected_username: "mike_hostetler"}} =
             Identity.from_runtime(runtime)

    assert :ok = Identity.validate_endpoint(runtime.credential_lease)

    explicit_endpoint =
      put_in(runtime.credential_lease.fields[:mcp_endpoint].transport, {
        :streamable_http,
        [base_url: Contract.base_url(), mcp_path: Contract.mcp_path()]
      })

    assert :ok = Identity.validate_endpoint(explicit_endpoint.credential_lease)

    assert {:ok, endpoint_struct} =
             Jido.Connect.MCP.Endpoint.new(
               "x-test",
               explicit_endpoint.credential_lease.fields.mcp_endpoint
             )

    struct_endpoint =
      put_in(runtime.credential_lease.fields[:mcp_endpoint], endpoint_struct)

    assert :ok = Identity.validate_endpoint(struct_endpoint.credential_lease)

    invalid_runtimes = [
      put_in(runtime.context.connection.provider, :mcp),
      put_in(runtime.context.connection.profile, :endpoint),
      put_in(runtime.context.connection.owner_type, :tenant),
      put_in(runtime.context.connection.metadata[:mcp_endpoint_id], "other"),
      put_in(runtime.context.connection.metadata[:expected_username], "@mike"),
      put_in(
        runtime.context.connection.metadata["expected_username"],
        "duplicate_user"
      ),
      update_in(runtime.context.connection.metadata, &Map.delete(&1, :expected_username))
    ]

    for invalid <- invalid_runtimes do
      assert {:error, %Error.AuthError{}} = Identity.from_runtime(invalid)
    end
  end

  test "rejects all non-exact loopback endpoint forms without exposing endpoint secrets" do
    runtime = runtime()

    invalid_urls = [
      "http://localhost:8000/mcp",
      "http://127.0.0.1/mcp",
      "http://127.0.0.1:8001/mcp",
      "https://127.0.0.1:8000/mcp",
      "http://127.0.0.2:8000/mcp",
      "http://[::1]:8000/mcp",
      "http://192.168.1.5:8000/mcp",
      "http://user@127.0.0.1:8000/mcp",
      "http://127.0.0.1:8000/other",
      "http://127.0.0.1:8000/mcp?endpoint=other",
      "http://127.0.0.1:8000/mcp#other"
    ]

    for url <- invalid_urls do
      invalid = put_in(runtime.credential_lease.fields[:mcp_endpoint].transport, endpoint(url))

      assert {:error, %Error.AuthError{reason: :x_mcp_endpoint_mismatch} = error} =
               Identity.validate_endpoint(invalid.credential_lease)

      rendered = inspect(error) <> inspect(Error.to_map(error))
      refute rendered =~ "local-secret"
      refute rendered =~ url
    end
  end

  test "maps each action to one exact remote tool and provider argument shape" do
    account = %{id: "x-user-1", username: "mike_hostetler", name: "Mike"}

    cases = [
      {"x.account.get", %{}, %{}},
      {"x.bookmark.list", %{max_results: 20, pagination_token: nil},
       %{id: "x-user-1", max_results: 20}},
      {"x.bookmark.list", %{max_results: 25, pagination_token: "next"},
       %{id: "x-user-1", max_results: 25, pagination_token: "next"}},
      {"x.post.list", %{max_results: 5, pagination_token: "newer"},
       %{id: "x-user-1", max_results: 5, pagination_token: "newer"}}
    ]

    for {action_id, input, expected_arguments} <- cases do
      descriptor = Contract.fetch_action!(action_id)
      assert Router.tool(descriptor) == descriptor.tool
      assert Router.arguments(descriptor, input, account) == expected_arguments
    end
  end

  defp runtime do
    connection =
      Connection.new!(%{
        id: "x-1",
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
          expected_username: "Mike_Hostetler",
          connection_revision: 1
        }
      })

    lease =
      CredentialLease.from_connection!(
        connection,
        %{
          mcp_endpoint: %{
            transport: endpoint(Contract.endpoint()),
            client_info: %{name: "x-test"},
            client_options: [private: "local-secret"]
          }
        },
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second),
        metadata: %{credential_version: 1}
      )

    %{
      context:
        Context.new!(%{
          tenant_id: "tenant-1",
          actor: %{id: "user-1", type: :user},
          connection: connection
        }),
      credential_lease: lease,
      credentials: lease.fields
    }
  end

  defp endpoint(url),
    do: {:streamable_http, [url: url, headers: [{"authorization", "Bearer local-secret"}]]}
end
