defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.CreatePermissionTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOnedrive.Handlers.Actions.CreatePermission

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
    test "invites a user to a drive item" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/me/drive/items/01ABCD1234/invite"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["recipients"] == [%{"email" => "carol@contoso.com"}]
        assert decoded["roles"] == ["read"]
        assert decoded["sendInvitation"] == true

        Req.Test.json(conn, %{
          "value" => [
            %{
              "id" => "PERM_NEW1",
              "roles" => ["read"],
              "grantedTo" => %{
                "user" => %{
                  "displayName" => "Carol Davis",
                  "email" => "carol@contoso.com"
                }
              },
              "shareId" => "SHARE_NEW1"
            }
          ]
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{permission: perm}} =
               CreatePermission.run(
                 %{
                   item_id: "01ABCD1234",
                   recipients: [%{email: "carol@contoso.com"}],
                   roles: ["read"]
                 },
                 context
               )

      assert perm.permission_id == "PERM_NEW1"
      assert perm.roles == ["read"]
      assert perm.granted_to.user.display_name == "Carol Davis"
    end

    test "invites multiple users with custom message" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert length(decoded["recipients"]) == 2
        assert decoded["message"] == "Please review this document."

        Req.Test.json(conn, %{
          "value" => [
            %{
              "id" => "PERM_MULTI1",
              "roles" => ["write"],
              "grantedTo" => %{
                "user" => %{"displayName" => "User One", "email" => "user1@contoso.com"}
              }
            },
            %{
              "id" => "PERM_MULTI2",
              "roles" => ["write"],
              "grantedTo" => %{
                "user" => %{"displayName" => "User Two", "email" => "user2@contoso.com"}
              }
            }
          ]
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{permission: perm}} =
               CreatePermission.run(
                 %{
                   item_id: "01ABCD1234",
                   recipients: [
                     %{email: "user1@contoso.com"},
                     %{email: "user2@contoso.com"}
                   ],
                   roles: ["write"],
                   message: "Please review this document."
                 },
                 context
               )

      assert perm.roles == ["write"]
    end

    test "returns error when item_id is missing" do
      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, :item_id_required} =
               CreatePermission.run(
                 %{recipients: [%{email: "a@b.com"}], roles: ["read"]},
                 context
               )
    end

    test "returns error when recipients is missing" do
      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, :recipients_required} =
               CreatePermission.run(%{item_id: "01ABCD1234", roles: ["read"]}, context)
    end

    test "returns error when recipients is empty" do
      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, :recipients_required} =
               CreatePermission.run(
                 %{item_id: "01ABCD1234", roles: ["read"], recipients: []},
                 context
               )
    end

    test "returns error when roles is missing" do
      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, :roles_required} =
               CreatePermission.run(
                 %{item_id: "01ABCD1234", recipients: [%{email: "a@b.com"}]},
                 context
               )
    end

    test "returns error when roles is empty" do
      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, :roles_required} =
               CreatePermission.run(
                 %{item_id: "01ABCD1234", recipients: [%{email: "a@b.com"}], roles: []},
                 context
               )
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = CreatePermission.run(%{}, %{})
    end

    test "returns error for HTTP 403" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(403), %{
          "error" => %{"code" => "accessDenied", "message" => "Access is denied."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 403}} =
               CreatePermission.run(
                 %{item_id: "01ABCD1234", recipients: [%{email: "a@b.com"}], roles: ["read"]},
                 context
               )
    end
  end
end
