defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.ListPermissionsTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOnedrive.Handlers.Actions.ListPermissions

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
    test "lists permissions for a drive item" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/me/drive/items/01ABCD1234/permissions"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        Req.Test.json(conn, %{
          "value" => [
            %{
              "id" => "PERM1",
              "roles" => ["read"],
              "grantedTo" => %{
                "user" => %{"displayName" => "Bob Smith", "email" => "bob@contoso.com"}
              }
            },
            %{
              "id" => "PERM2",
              "roles" => ["write"],
              "link" => %{
                "type" => "edit",
                "webUrl" => "https://contoso.sharepoint.com/:w:/r/Shared"
              }
            }
          ]
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{permissions: permissions}} =
               ListPermissions.run(%{item_id: "01ABCD1234"}, context)

      assert length(permissions) == 2
      [first, second] = permissions
      assert first.permission_id == "PERM1"
      assert first.roles == ["read"]
      assert first.granted_to.user.display_name == "Bob Smith"
      assert second.permission_id == "PERM2"
      assert second.roles == ["write"]
      assert second.link.type == "edit"
    end

    test "handles empty permissions" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"value" => []})
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{permissions: []}} =
               ListPermissions.run(%{item_id: "01ABCD1234"}, context)
    end

    test "returns error when item_id is missing" do
      context = %{credentials: %{access_token: "test-token"}}
      assert {:error, :item_id_required} = ListPermissions.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = ListPermissions.run(%{}, %{})
    end

    test "returns error for HTTP 404" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(404), %{
          "error" => %{"message" => "The specified item was not found."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               ListPermissions.run(%{item_id: "nonexistent"}, context)
    end
  end
end
