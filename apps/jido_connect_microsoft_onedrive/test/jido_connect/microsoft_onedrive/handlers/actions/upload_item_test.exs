defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.UploadItemTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOnedrive.Handlers.Actions.UploadItem

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
    test "uploads a file to drive root" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == "/me/drive/root:/notes.txt:/content"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        Req.Test.json(conn |> Plug.Conn.put_status(201), %{
          "id" => "01UPLOADED1",
          "name" => "notes.txt",
          "size" => 11,
          "file" => %{"mimeType" => "text/plain"}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{item: item}} =
               UploadItem.run(%{name: "notes.txt", content: "hello world"}, context)

      assert item.item_id == "01UPLOADED1"
      assert item.name == "notes.txt"
      assert item.size == 11
    end

    test "uploads a file under a specific parent" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/me/drive/items/01PARENT:/report.pdf:/content"

        Req.Test.json(conn |> Plug.Conn.put_status(201), %{
          "id" => "01UPLOADED2",
          "name" => "report.pdf",
          "size" => 2048
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{item: item}} =
               UploadItem.run(
                 %{name: "report.pdf", content: "<<pdf>>", parent_id: "01PARENT"},
                 context
               )

      assert item.item_id == "01UPLOADED2"
      assert item.name == "report.pdf"
    end

    test "returns error when name is missing" do
      context = %{credentials: %{access_token: "test-token"}}
      assert {:error, :name_required} = UploadItem.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = UploadItem.run(%{}, %{})
    end

    test "returns error for HTTP 413 payload too large" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(413), %{
          "error" => %{"message" => "The file size exceeds the limit."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 413}} =
               UploadItem.run(%{name: "big.zip", content: "x"}, context)
    end
  end
end
