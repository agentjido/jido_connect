defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.ListItemsTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOnedrive.Handlers.Actions.ListItems

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
    test "lists root children by default" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/me/drive/root/children"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]
        assert conn.query_params["$top"] == "25"

        Req.Test.json(conn, %{
          "@odata.context" =>
            "https://graph.microsoft.com/v1.0/$metadata#users('user')/drive/items",
          "@odata.nextLink" => "https://graph.microsoft.com/v1.0/me/drive/root/children?$skip=25",
          "value" => [
            %{
              "id" => "01ABCD1234",
              "name" => "Quarterly Report.docx",
              "size" => 1024,
              "file" => %{
                "mimeType" =>
                  "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
              }
            },
            %{
              "id" => "01FOLDER1",
              "name" => "Reports",
              "size" => 5120,
              "folder" => %{"childCount" => 12}
            }
          ]
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}
      assert {:ok, %{items: items, next_link: next_link}} = ListItems.run(%{}, context)

      assert length(items) == 2
      [first, second] = items
      assert first.item_id == "01ABCD1234"
      assert first.name == "Quarterly Report.docx"
      assert second.item_id == "01FOLDER1"
      assert second.name == "Reports"
      assert next_link =~ "$skip=25"
    end

    test "lists children of a specific folder via parent_id" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/me/drive/items/01FOLDER1/children"

        Req.Test.json(conn, %{
          "value" => [
            %{"id" => "01CHILD1", "name" => "Nested File.txt"}
          ]
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{items: items}} =
               ListItems.run(%{parent_id: "01FOLDER1"}, context)

      assert length(items) == 1
      assert hd(items).name == "Nested File.txt"
    end

    test "handles empty result" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"value" => []})
      end)

      context = %{credentials: %{access_token: "test-token"}}
      assert {:ok, %{items: [], next_link: nil}} = ListItems.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = ListItems.run(%{}, %{})
    end

    test "returns error for HTTP error responses" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(500), %{
          "error" => %{"message" => "Internal server error"}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               ListItems.run(%{}, context)
    end

    test "returns error for HTTP 429 rate limited" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Plug.Conn.put_resp_header("retry-after", "30")
        |> Req.Test.json(%{
          "error" => %{"code" => "TooManyRequests", "message" => "Please retry later."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 429}} =
               ListItems.run(%{}, context)
    end

    test "passes custom page_size" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.query_params["$top"] == "10"

        Req.Test.json(conn, %{"value" => []})
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{items: []}} = ListItems.run(%{page_size: 10}, context)
    end
  end
end
