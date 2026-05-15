defmodule Jido.Connect.Google.Docs.StructTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Docs.{
    Document,
    DocumentRequest,
    DocumentResult,
    Tab
  }

  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "document struct validates with Zoi" do
    document =
      ConnectorContracts.assert_struct_defaults(
        Document,
        %{document_id: "doc_abc123"},
        tabs: [],
        metadata: %{}
      )

    assert document.document_id == "doc_abc123"
    assert {:error, _error} = Document.new(%{})
  end

  test "document struct accepts full attributes" do
    document =
      Document.new!(%{
        document_id: "doc_abc123",
        title: "Project Plan",
        revision_id: "rev001",
        suggestions_view_mode: "SUGGESTIONS_INLINE",
        body: %{"content" => []},
        document_style: %{"pageSize" => %{}},
        named_styles: %{"styles" => []}
      })

    assert document.title == "Project Plan"
    assert document.revision_id == "rev001"
    assert document.body == %{"content" => []}
  end

  test "tab struct validates with Zoi" do
    tab =
      ConnectorContracts.assert_struct_defaults(
        Tab,
        %{tab_id: "tab_summary", title: "Summary"},
        metadata: %{}
      )

    assert tab.tab_id == "tab_summary"
    assert tab.title == "Summary"
  end

  test "tab struct accepts empty optional fields" do
    tab = Tab.new!(%{})
    assert tab.metadata == %{}
  end

  test "document request struct validates with Zoi" do
    request =
      ConnectorContracts.assert_struct_defaults(
        DocumentRequest,
        %{title: "New Document", body: %{"content" => []}},
        metadata: %{}
      )

    assert request.title == "New Document"
    assert request.body == %{"content" => []}
  end

  test "document request struct accepts revision_id for update" do
    request =
      DocumentRequest.new!(%{
        title: "Updated Title",
        body: %{"content" => []},
        revision_id: "rev001"
      })

    assert request.revision_id == "rev001"
  end

  test "document result struct validates with Zoi" do
    result =
      ConnectorContracts.assert_struct_defaults(
        DocumentResult,
        %{document_id: "doc_abc123", title: "Created Doc", revision_id: "rev001"},
        metadata: %{}
      )

    assert result.document_id == "doc_abc123"
    assert result.title == "Created Doc"
    assert result.revision_id == "rev001"
  end

  test "document result struct accepts partial fields" do
    result = DocumentResult.new!(%{})
    assert result.document_id == nil
    assert result.metadata == %{}
  end
end
