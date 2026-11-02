defmodule Jido.Connect.Google.Docs.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Google.Docs.{Client, Document, Tab}
  alias Jido.Connect.TestSupport.LiveSmoke

  @tabbed_document_id "1Ej83l690dmUeDhX90Suxdef_SR97A-Kleilmdg5G9_E"
  @scratch_document_id "1t47PcdwCWroHLmzucoB5YxoFZRyUD9a8dymU8ju-pwE"

  # The two-request batch of the insert recording, in Google's camelCase
  # spelling. The recorded response holds one empty reply per request.
  @insert_batch [
    %{
      "insertText" => %{
        "location" => %{"index" => 1, "tabId" => "t.0"},
        "text" => "jcl-live-second\n"
      }
    },
    %{
      "insertText" => %{
        "location" => %{"index" => 1, "tabId" => "t.0"},
        "text" => "jcl-live-first\n"
      }
    }
  ]

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
    recorded = LiveSmoke.fixture!(:google_docs, "document_with_tabs_content")
    %{"tabs" => [first, second]} = recorded

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v1/documents/#{@tabbed_document_id}"
      assert conn.query_params["includeTabsContent"] == "true"

      Req.Test.json(conn, recorded)
    end)

    assert {:ok, %Document{} = document} =
             Client.get_document(
               %{document_id: @tabbed_document_id, include_tabs_content: true},
               "token"
             )

    assert [
             %Tab{tab_id: "t.0", title: "First", body: first_body},
             %Tab{tab_id: "t.1mzp8ctna0b6", title: "Second", body: second_body}
           ] = document.tabs

    assert first_body == first["documentTab"]["body"]
    assert second_body == second["documentTab"]["body"]
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

  # The client passes request keys through unchanged, so camelCase input goes
  # out as camelCase. The responses are the recordings of the scratch document.
  test "batch updates document" do
    recorded = LiveSmoke.fixture!(:google_docs, "batch_update_insert")

    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/documents/#{@scratch_document_id}:batchUpdate"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      decoded = Jason.decode!(body)
      assert decoded["requests"] == @insert_batch
      assert decoded["writeControl"] == %{"requiredRevisionId" => "rev001"}

      Req.Test.json(conn, recorded)
    end)

    assert {:ok, result} =
             Client.batch_update(
               %{
                 document_id: @scratch_document_id,
                 requests: @insert_batch,
                 write_control: %{"requiredRevisionId" => "rev001"}
               },
               "token"
             )

    assert result == %{
             document_id: @scratch_document_id,
             replies: [%{}, %{}],
             write_control: recorded["writeControl"]
           }
  end

  test "batch updates document without write control" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v1/documents/#{@scratch_document_id}:batchUpdate"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      decoded = Jason.decode!(body)
      assert decoded["requests"] == @insert_batch
      refute Map.has_key?(decoded, "writeControl")

      Req.Test.json(conn, LiveSmoke.fixture!(:google_docs, "batch_update_insert"))
    end)

    assert {:ok, %{document_id: @scratch_document_id, replies: replies}} =
             Client.batch_update(
               %{document_id: @scratch_document_id, requests: @insert_batch},
               "token"
             )

    assert replies == [%{}, %{}]
  end

  # The recorded rejection answers one insert whose required revision is no
  # longer the latest.
  test "handles batch update API error response" do
    recorded = LiveSmoke.fixture!(:google_docs, "batch_update_stale_revision")

    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(400)
      |> Req.Test.json(recorded)
    end)

    assert {:error, %Jido.Connect.Error.ProviderError{reason: :http_error, status: 400} = error} =
             Client.batch_update(
               %{
                 document_id: @scratch_document_id,
                 requests: Enum.take(@insert_batch, 1),
                 write_control: %{"requiredRevisionId" => "stale-revision"}
               },
               "token"
             )

    assert error.details.message == recorded["error"]["message"]
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
