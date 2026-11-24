defmodule Jido.Connect.Google.Docs.FixtureTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Docs.Normalizer
  alias Jido.Connect.Google.TestSupport.ConnectorContracts
  alias Jido.Connect.TestSupport.LiveSmoke

  test "normalizes common Google Docs document fixture" do
    payload = fixture!("document_common.json")

    assert {:ok, doc} = Normalizer.document(payload)
    assert doc.document_id == "doc_abc123"
    assert doc.title == "Project Plan"
    assert doc.revision_id == "rev001"
    assert doc.suggestions_view_mode == "SUGGESTIONS_INLINE"
    assert doc.body != nil
    assert doc.document_style != nil
    assert doc.named_styles != nil
    assert doc.tabs == []
  end

  test "normalizes the recorded multi-tab document" do
    payload = LiveSmoke.fixture!(:google_docs, "document_with_tabs_content")

    assert {:ok, doc} = Normalizer.document(payload)
    assert doc.document_id == "1Ej83l690dmUeDhX90Suxdef_SR97A-Kleilmdg5G9_E"
    assert doc.title == "jcl-live tabs"
    assert doc.body == nil

    assert [%{tab_id: "t.0", title: "First"}, %{tab_id: "t.1mzp8ctna0b6", title: "Second"}] =
             doc.tabs
  end

  test "normalizes minimal Google Docs document fixture" do
    payload = fixture!("document_minimal.json")

    assert {:ok, doc} = Normalizer.document(payload)
    assert doc.document_id == "doc_min789"
    assert doc.title == "Minimal Doc"
    assert doc.revision_id == "rev003"
    assert doc.body == nil
    assert doc.document_style == nil
    assert doc.tabs == []
  end

  test "normalizes the recorded batch update response" do
    payload = LiveSmoke.fixture!(:google_docs, "batch_update_insert")

    assert {:ok, result} = Normalizer.batch_update_result(payload)

    assert result == %{
             document_id: "1t47PcdwCWroHLmzucoB5YxoFZRyUD9a8dymU8ju-pwE",
             replies: [%{}, %{}],
             write_control: %{
               "requiredRevisionId" => payload["writeControl"]["requiredRevisionId"]
             }
           }
  end

  test "normalizes a recorded document read placed inline in a batch update response" do
    document = LiveSmoke.fixture!(:google_docs, "document_without_tabs_content")

    payload =
      :google_docs
      |> LiveSmoke.fixture!("batch_update_insert")
      |> Map.put("document", document)

    assert {:ok, %{document: inline}} = Normalizer.batch_update_result(payload)
    assert %{document_id: "1Ej83l690dmUeDhX90Suxdef_SR97A-Kleilmdg5G9_E", tabs: []} = inline
    assert inline.body == document["body"]
  end

  test "normalizes a recorded tab from tabProperties and documentTab" do
    %{"tabs" => [first | _rest]} = LiveSmoke.fixture!(:google_docs, "document_with_tabs_content")

    assert {:ok, tab} = Normalizer.tab(first)
    assert tab.tab_id == "t.0"
    assert tab.title == "First"
    assert tab.body == first["documentTab"]["body"]

    assert %{
             "content" => [
               %{"endIndex" => 1, "sectionBreak" => _},
               %{
                 "startIndex" => 1,
                 "endIndex" => 22,
                 "paragraph" => %{
                   "elements" => [%{"textRun" => %{"content" => "jcl-marker-tab-first\n"}}]
                 }
               },
               %{"startIndex" => 22, "endIndex" => 23}
             ]
           } = tab.body
  end

  test "normalizes document request" do
    payload = %{
      "title" => "New Document",
      "body" => %{"content" => []}
    }

    assert {:ok, request} = Normalizer.document_request(payload)
    assert request.title == "New Document"
    assert request.body == %{"content" => []}
    assert request.revision_id == nil
  end

  test "normalizes document request with revision" do
    payload = %{
      "title" => "Updated Title",
      "body" => %{"content" => []},
      "revisionId" => "rev004"
    }

    assert {:ok, request} = Normalizer.document_request(payload)
    assert request.revision_id == "rev004"
  end

  defp fixture!(name) do
    ConnectorContracts.google_fixture!(:google_docs, name, __DIR__)
  end
end
