defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.CreateSharingLinkTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOnedrive.Handlers.Actions.CreateSharingLink

  setup do
    Application.put_env(:jido_connect_microsoft, :microsoft_graph_base_url, "https://graph.test")

    Application.put_env(:jido_connect_microsoft, :microsoft_req_options,
      plug: {Req.Test, __MODULE__},
      retry: false
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_microsoft, :microsoft_graph_base_url)
      Application.delete_env(:jido_connect_microsoft, :microsoft_req_options)
    end)
  end

  describe "run/2" do
    test "creates a view sharing link" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/me/drive/items/01ABCD1234/createLink"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["type"] == "view"
        assert decoded["retainInheritedPermissions"] == true

        Req.Test.json(conn |> Plug.Conn.put_status(201), %{
          "id" => "PERM_LINK1",
          "roles" => ["read"],
          "link" => %{
            "type" => "view",
            "webUrl" => "https://contoso-my.sharepoint.com/:w:/r/personal/user/Documents/Shared"
          },
          "shareId" => "SHARE_LINK1"
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{permission: perm}} =
               CreateSharingLink.run(%{item_id: "01ABCD1234", type: "view"}, context)

      assert perm.permission_id == "PERM_LINK1"
      assert perm.roles == ["read"]
      assert perm.link.type == "view"
      assert perm.link.link =~ "contoso-my.sharepoint.com"
    end

    test "creates an edit sharing link with scope and password" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["type"] == "edit"
        assert decoded["scope"] == "organization"
        assert decoded["password"] == "secret123"

        Req.Test.json(conn |> Plug.Conn.put_status(201), %{
          "id" => "PERM_LINK2",
          "roles" => ["write"],
          "link" => %{
            "type" => "edit",
            "webUrl" => "https://contoso-my.sharepoint.com/:w:/r/personal/user/Documents/Edit"
          },
          "hasPassword" => true
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{permission: perm}} =
               CreateSharingLink.run(
                 %{
                   item_id: "01ABCD1234",
                   type: "edit",
                   scope: "organization",
                   password: "secret123"
                 },
                 context
               )

      assert perm.roles == ["write"]
      assert perm.link.type == "edit"
      assert perm.has_password == true
    end

    test "returns error when item_id is missing" do
      context = %{credentials: %{access_token: "test-token"}}
      assert {:error, :item_id_required} = CreateSharingLink.run(%{type: "view"}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = CreateSharingLink.run(%{}, %{})
    end

    test "returns error for HTTP 403" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(403), %{
          "error" => %{"code" => "accessDenied", "message" => "Access is denied."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 403}} =
               CreateSharingLink.run(%{item_id: "restricted", type: "view"}, context)
    end
  end
end
