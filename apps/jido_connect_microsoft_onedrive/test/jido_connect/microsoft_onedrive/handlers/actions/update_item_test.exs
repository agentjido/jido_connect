defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.UpdateItemTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOnedrive.Handlers.Actions.UpdateItem

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
    test "updates an item name" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/me/drive/items/01ABCD1234"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        assert %{"name" => "Renamed.docx"} = Jason.decode!(body)

        Req.Test.json(conn, %{
          "id" => "01ABCD1234",
          "name" => "Renamed.docx",
          "size" => 1024,
          "file" => %{
            "mimeType" =>
              "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
          }
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{item: item}} =
               UpdateItem.run(%{item_id: "01ABCD1234", name: "Renamed.docx"}, context)

      assert item.item_id == "01ABCD1234"
      assert item.name == "Renamed.docx"
    end

    test "returns error when item_id is missing" do
      context = %{credentials: %{access_token: "test-token"}}
      assert {:error, :item_id_required} = UpdateItem.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = UpdateItem.run(%{}, %{})
    end

    test "returns error for HTTP 404" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(404), %{
          "error" => %{"message" => "The specified item was not found."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               UpdateItem.run(%{item_id: "nonexistent", name: "x"}, context)
    end
  end
end
