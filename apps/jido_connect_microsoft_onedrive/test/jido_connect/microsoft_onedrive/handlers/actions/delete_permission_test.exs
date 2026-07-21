defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.DeletePermissionTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOnedrive.Handlers.Actions.DeletePermission

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
    test "deletes a permission from a drive item" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/me/drive/items/01ABCD1234/permissions/PERM1"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        conn |> Plug.Conn.put_status(204) |> Plug.Conn.send_resp(204, "")
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{deleted: true, permission_id: "PERM1"}} =
               DeletePermission.run(%{item_id: "01ABCD1234", permission_id: "PERM1"}, context)
    end

    test "returns error when item_id is missing" do
      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, :item_id_required} =
               DeletePermission.run(%{permission_id: "PERM1"}, context)
    end

    test "returns error when permission_id is missing" do
      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, :permission_id_required} =
               DeletePermission.run(%{item_id: "01ABCD1234"}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = DeletePermission.run(%{}, %{})
    end

    test "returns error for HTTP 403" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(403), %{
          "error" => %{"code" => "accessDenied", "message" => "Access is denied."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 403}} =
               DeletePermission.run(%{item_id: "restricted", permission_id: "PERM1"}, context)
    end

    test "returns error for HTTP 404" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(404), %{
          "error" => %{"message" => "The specified permission was not found."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               DeletePermission.run(
                 %{item_id: "01ABCD1234", permission_id: "nonexistent"},
                 context
               )
    end
  end
end
