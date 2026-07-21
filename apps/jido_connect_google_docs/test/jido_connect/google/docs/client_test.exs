defmodule Jido.Connect.Google.Docs.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Google.Docs.{Client, Document}

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(
      :jido_connect_google_docs,
      :google_docs_api_base_url,
      "https://docs.test"
    )

    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_google_docs, :google_docs_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  test "gets document" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/documents/doc_abc123"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]

      Req.Test.json(conn, document_payload())
    end)

    assert {:ok, %Document{} = document} =
             Client.get_document(%{document_id: "doc_abc123"}, "token")

    assert document.document_id == "doc_abc123"
    assert document.title == "Project Plan"
  end

  test "gets document with suggestions view mode" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/documents/doc_abc123"
      assert conn.query_params["suggestionsViewMode"] == "SUGGESTIONS_INLINE"

      Req.Test.json(conn, document_payload())
    end)

    assert {:ok, %Document{} = document} =
             Client.get_document(
               %{document_id: "doc_abc123", suggestions_view_mode: "SUGGESTIONS_INLINE"},
               "token"
             )

    assert document.document_id == "doc_abc123"
  end

  test "gets document with tab content" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/documents/doc_abc123"
      assert conn.query_params["includeTabsContent"] == "true"

      Req.Test.json(conn, %{
        "documentId" => "doc_abc123",
        "title" => "Project Plan",
        "tabs" => [
          %{
            "tabProperties" => %{"id" => "tab_summary", "title" => "Summary"},
            "documentTab" => %{"body" => %{"content" => []}}
          }
        ]
      })
    end)

    assert {:ok, %Document{} = document} =
             Client.get_document(
               %{document_id: "doc_abc123", include_tabs_content: true},
               "token"
             )

    assert [%{tab_id: "tab_summary", title: "Summary"}] = document.tabs
  end

  test "creates document" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/documents"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "title" => "New Project Plan"
             }

      Req.Test.json(conn, %{
        "documentId" => "doc_new001",
        "title" => "New Project Plan",
        "revisionId" => "rev001"
      })
    end)

    assert {:ok, %Document{} = document} =
             Client.create_document(%{title: "New Project Plan"}, "token")

    assert document.document_id == "doc_new001"
    assert document.title == "New Project Plan"
  end

  test "rejects malformed document response" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, ["bad"])
    end)

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Client.get_document(%{document_id: "doc_abc123"}, "token")
  end

  test "handles API error response" do
    Req.Test.stub(__MODULE__, fn conn ->
      Plug.Conn.send_resp(conn, 404, Jason.encode!(%{"error" => %{"message" => "not found"}}))
    end)

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :http_error, status: 404}} =
             Client.get_document(%{document_id: "nonexistent"}, "token")
  end

  test "batch updates document" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/documents/doc_abc123:batchUpdate"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      decoded = Jason.decode!(body)
      assert decoded["requests"] == [%{"insertText" => %{"text" => "Hello"}}]
      assert decoded["writeControl"] == %{"requiredRevisionId" => "rev001"}

      Req.Test.json(conn, %{
        "documentId" => "doc_abc123",
        "replies" => [%{"insertText" => %{}}]
      })
    end)

    assert {:ok, result} =
             Client.batch_update(
               %{
                 document_id: "doc_abc123",
                 requests: [%{insertText: %{text: "Hello"}}],
                 write_control: %{requiredRevisionId: "rev001"}
               },
               "token"
             )

    assert result.document_id == "doc_abc123"
    assert length(result.replies) == 1
  end

  test "batch updates document without write control" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/documents/doc_abc123:batchUpdate"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      decoded = Jason.decode!(body)
      assert decoded["requests"] == [%{"insertText" => %{"text" => "Hello"}}]
      refute Map.has_key?(decoded, "writeControl")

      Req.Test.json(conn, %{
        "documentId" => "doc_abc123",
        "replies" => []
      })
    end)

    assert {:ok, result} =
             Client.batch_update(
               %{
                 document_id: "doc_abc123",
                 requests: [%{insertText: %{text: "Hello"}}]
               },
               "token"
             )

    assert result.document_id == "doc_abc123"
    assert result.replies == []
  end

  test "handles batch update API error response" do
    Req.Test.stub(__MODULE__, fn conn ->
      Plug.Conn.send_resp(conn, 400, Jason.encode!(%{"error" => %{"message" => "bad request"}}))
    end)

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :http_error, status: 400}} =
             Client.batch_update(
               %{document_id: "doc_abc123", requests: [%{insertText: %{}}]},
               "token"
             )
  end

  test "handles batch update malformed response" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, ["bad"])
    end)

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
             Client.batch_update(
               %{document_id: "doc_abc123", requests: [%{insertText: %{}}]},
               "token"
             )
  end

  defp document_payload do
    %{
      "documentId" => "doc_abc123",
      "title" => "Project Plan",
      "revisionId" => "rev001"
    }
  end
end
