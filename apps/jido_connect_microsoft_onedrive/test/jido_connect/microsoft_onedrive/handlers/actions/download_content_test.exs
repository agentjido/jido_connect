defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.DownloadContentTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOnedrive.Handlers.Actions.DownloadContent

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
    test "downloads text content" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/me/drive/items/01ABCD1234/content"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        conn
        |> Plug.Conn.put_resp_content_type("text/plain")
        |> Plug.Conn.send_resp(200, "Hello, World!")
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, content} = DownloadContent.run(%{item_id: "01ABCD1234"}, context)

      assert content.item_id == "01ABCD1234"
      assert content.content == "Hello, World!"
      assert content.size == 13
      assert content.binary == false
      assert content.encoding == "utf-8"
      refute Map.has_key?(content, :content_base64)
    end

    test "downloads binary content as base64" do
      binary_data = <<0, 1, 2, 3, 255, 254, 253>>

      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("image/jpeg")
        |> Plug.Conn.send_resp(200, binary_data)
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, content} = DownloadContent.run(%{item_id: "01IMG123"}, context)

      assert content.item_id == "01IMG123"
      assert content.mime_type == "image/jpeg"
      assert content.size == 7
      assert content.binary == true
      assert content.encoding == "base64"
      assert content.content_base64 == Base.encode64(binary_data)
      refute Map.has_key?(content, :content)
    end

    test "returns error when item_id is missing" do
      context = %{credentials: %{access_token: "test-token"}}
      assert {:error, :item_id_required} = DownloadContent.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = DownloadContent.run(%{}, %{})
    end

    test "returns error for HTTP 404" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(404), %{
          "error" => %{"message" => "The specified item was not found."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               DownloadContent.run(%{item_id: "nonexistent"}, context)
    end

    test "returns error for HTTP error responses" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(500), %{
          "error" => %{"message" => "Internal server error"}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               DownloadContent.run(%{item_id: "01ERR"}, context)
    end

    test "returns error for non-JSON body with download URL (no binary content)" do
      # When Graph returns a JSON body with @microsoft.graph.downloadUrl but no
      # binary content directly, the handler treats it as an error because the
      # response body was JSON rather than binary content.
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "@microsoft.graph.downloadUrl" => "https://download.test/file.bin",
          "id" => "01JSON"
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               DownloadContent.run(%{item_id: "01JSON"}, context)
    end
  end
end
