defmodule Jido.Connect.Notion.Handlers.Actions.GetPageTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.Notion
  alias Jido.Connect.Notion.Handlers.Actions.GetPage

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_notion, :notion_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_notion, :notion_req_options)
    end)
  end

  test "run/2 returns page struct" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        "id" => "page-001",
        "archived" => false,
        "url" => "https://www.notion.so/page-001",
        "properties" => %{},
        "parent" => %{"type" => "workspace", "workspace" => true}
      })
    end)

    assert {:ok, %{page: page}} =
             GetPage.run(%{page_id: "page-001"}, %{credentials: %{api_key: "test-key"}})

    assert page.id == "page-001"
    assert page.archived == false
  end

  for {profile, field} <- [oauth2: :access_token, internal_token: :api_key] do
    test "sends the #{profile} lease token as a bearer token" do
      profile = unquote(profile)
      field = unquote(field)
      token = "test-#{profile}-token"

      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/v1/pages/page-001"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer #{token}"]

        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"message" => "Page not found"})
      end)

      connection =
        Connect.Connection.new!(%{
          id: "conn_1",
          provider: :notion,
          profile: profile,
          tenant_id: "tenant_1",
          owner_type: :app_user,
          owner_id: "user_1",
          status: :connected,
          scopes: ["read_content"]
        })

      context =
        Connect.Context.new!(%{
          tenant_id: connection.tenant_id,
          actor: %{id: connection.owner_id, type: :user},
          connection: connection
        })

      lease =
        Connect.CredentialLease.new!(%{
          connection_id: connection.id,
          provider: connection.provider,
          profile: profile,
          expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
          fields: %{field => token},
          scopes: connection.scopes
        })

      assert {:error, %Connect.Error.ProviderError{provider: :notion, status: 404}} =
               Connect.invoke(Notion, "notion.page.get", %{page_id: "page-001"},
                 context: context,
                 credential_lease: lease,
                 policy: fn _operation, _input, _context, _connection -> :ok end
               )
    end
  end
end
