defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.DeleteItemTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOnedrive.Handlers.Actions.DeleteItem

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
    test "deletes an item by id" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "DELETE"
        assert conn.request_path == "/me/drive/items/01ABCD1234"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        conn |> Plug.Conn.put_status(204) |> Plug.Conn.send_resp(204, "")
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{deleted: true, item_id: "01ABCD1234"}} =
               DeleteItem.run(%{item_id: "01ABCD1234"}, context)
    end

    test "returns error when item_id is missing" do
      context = %{credentials: %{access_token: "test-token"}}
      assert {:error, :item_id_required} = DeleteItem.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = DeleteItem.run(%{}, %{})
    end

    test "returns error for HTTP 404" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(404), %{
          "error" => %{"message" => "The specified item was not found."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               DeleteItem.run(%{item_id: "nonexistent"}, context)
    end

    test "returns error for HTTP 403 forbidden" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(403), %{
          "error" => %{"code" => "accessDenied", "message" => "Access is denied."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 403}} =
               DeleteItem.run(%{item_id: "restricted"}, context)
    end
  end
end
