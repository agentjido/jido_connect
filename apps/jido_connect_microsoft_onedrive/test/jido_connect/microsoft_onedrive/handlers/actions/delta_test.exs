defmodule Jido.Connect.MicrosoftOnedrive.Handlers.Actions.DeltaTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftOnedrive.Handlers.Actions.Delta

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
    test "reads initial delta changes" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/me/drive/root/delta"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        Req.Test.json(conn, %{
          "@odata.deltaLink" =>
            "https://graph.microsoft.com/v1.0/me/drive/root/delta?token=MzslMjM0",
          "value" => [
            %{
              "id" => "01ABCD1234",
              "name" => "Quarterly Report.docx",
              "file" => %{
                "mimeType" =>
                  "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
              }
            },
            %{
              "id" => "01NEW5678",
              "name" => "Budget.xlsx",
              "file" => %{
                "mimeType" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
              }
            }
          ]
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}
      assert {:ok, result} = Delta.run(%{}, context)

      assert length(result.items) == 2
      assert [%{name: "Quarterly Report.docx"}, %{name: "Budget.xlsx"}] = result.items
      assert result.delta_link =~ "token=MzslMjM0"
      assert is_nil(result.next_link)
      assert is_nil(result.delta_token)
    end

    test "reads incremental delta with token" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path =~ ~r{/me/drive/root/delta\(token='TOKEN123'\)}

        Req.Test.json(conn, %{
          "@odata.deltaToken" => "NEW_TOKEN_456",
          "@odata.nextLink" =>
            "https://graph.microsoft.com/v1.0/me/drive/root/delta?token=NEW_TOKEN_456&$skip=25",
          "value" => [
            %{
              "id" => "01CHANGED",
              "name" => "Modified File.txt",
              "file" => %{"mimeType" => "text/plain"}
            }
          ]
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, result} = Delta.run(%{token: "TOKEN123"}, context)

      assert length(result.items) == 1
      assert hd(result.items).name == "Modified File.txt"
      assert result.next_link =~ "$skip=25"
      assert result.delta_token == "NEW_TOKEN_456"
    end

    test "handles empty delta response" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "@odata.deltaLink" =>
            "https://graph.microsoft.com/v1.0/me/drive/root/delta?token=EMPTY",
          "value" => []
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}
      assert {:ok, result} = Delta.run(%{}, context)

      assert result.items == []
      assert result.delta_link =~ "token=EMPTY"
      assert is_nil(result.next_link)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = Delta.run(%{}, %{})
    end

    test "returns error for HTTP error responses" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(500), %{
          "error" => %{"message" => "Internal server error"}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               Delta.run(%{}, context)
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
               Delta.run(%{}, context)
    end
  end
end
