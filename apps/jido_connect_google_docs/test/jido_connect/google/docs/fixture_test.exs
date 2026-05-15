defmodule Jido.Connect.Google.Docs.FixtureTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Docs.Normalizer
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

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

  test "normalizes multi-tab Google Docs document fixture" do
    payload = fixture!("document_tabs.json")

    assert {:ok, doc} = Normalizer.document(payload)
    assert doc.document_id == "doc_tabs456"
    assert doc.title == "Multi-Tab Report"
    assert doc.revision_id == "rev002"
    assert doc.body == nil
    assert length(doc.tabs) == 2

    [tab1, tab2] = doc.tabs
    assert tab1.tab_id == "tab_summary"
    assert tab1.title == "Summary"
    assert tab1.body != nil

    assert tab2.tab_id == "tab_details"
    assert tab2.title == "Details"
    assert tab2.body != nil
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

  test "normalizes Google Docs batch update result fixture" do
    payload = fixture!("batch_update_result.json")

    assert {:ok, result} = Normalizer.document_result(payload)
    assert result.document_id == "doc_batch101"
    assert result.title == "Batch Updated Doc"
    assert result.revision_id == "rev005"
  end

  test "normalizes tab directly" do
    payload = %{
      "tabProperties" => %{
        "id" => "tab_notes",
        "title" => "Notes"
      },
      "body" => %{"content" => []}
    }

    assert {:ok, tab} = Normalizer.tab(payload)
    assert tab.tab_id == "tab_notes"
    assert tab.title == "Notes"
    assert tab.body == %{"content" => []}
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
