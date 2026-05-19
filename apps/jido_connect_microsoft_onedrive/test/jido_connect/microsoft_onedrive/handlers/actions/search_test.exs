defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.SearchTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOnedrive.Handlers.Actions.Search

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
    test "searches for drive items matching a query" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path =~ ~r{/me/drive/root/search\(q='}
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        Req.Test.json(conn, %{
          "@odata.nextLink" =>
            "https://graph.microsoft.com/v1.0/me/drive/root/search(q='Quarterly')?$skip=25",
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
              "id" => "01EFGH5678",
              "name" => "Quarterly Budget.xlsx",
              "size" => 2048,
              "file" => %{
                "mimeType" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
              }
            }
          ]
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{items: items, next_link: next_link}} =
               Search.run(%{query: "Quarterly"}, context)

      assert length(items) == 2
      assert Enum.all?(items, &(&1.name =~ "Quarterly"))
      assert next_link =~ "$skip=25"
    end

    test "handles empty search results" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"value" => []})
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{items: [], next_link: nil}} =
               Search.run(%{query: "nonexistent"}, context)
    end

    test "returns error when query is missing" do
      context = %{credentials: %{access_token: "test-token"}}
      assert {:error, :query_required} = Search.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = Search.run(%{query: "test"}, %{})
    end

    test "returns error for HTTP error responses" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(500), %{
          "error" => %{"message" => "Internal server error"}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               Search.run(%{query: "test"}, context)
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
               Search.run(%{query: "test"}, context)
    end
  end
end
