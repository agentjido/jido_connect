defmodule Jido.Connect.Google.Docs.StructTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Docs.{
    BatchUpdateRequest,
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

  test "batch update request struct validates with Zoi" do
    request =
      ConnectorContracts.assert_struct_defaults(
        BatchUpdateRequest,
        %{document_id: "doc_abc123", requests: [%{insert_text: %{}}]},
        metadata: %{}
      )

    assert request.document_id == "doc_abc123"
    assert length(request.requests) == 1
  end

  test "batch update request struct accepts optional write_control" do
    request =
      BatchUpdateRequest.new!(%{
        document_id: "doc_abc123",
        requests: [%{insert_text: %{}}],
        write_control: %{required_revision_id: "rev001"}
      })

    assert request.write_control == %{required_revision_id: "rev001"}
  end

  test "batch update request struct rejects missing document_id" do
    assert {:error, _error} = BatchUpdateRequest.new(%{requests: [%{insert_text: %{}}]})
  end

  test "batch update request struct rejects missing requests" do
    assert {:error, _error} = BatchUpdateRequest.new(%{document_id: "doc_abc123"})
  end

  test "batch update request validate_requests accepts valid operations" do
    requests = [
      %{insert_text: %{text: "Hello", location: %{index: 1}}},
      %{update_text_style: %{range: %{start_index: 1, end_index: 6}}},
      %{insert_table: %{rows: 3, columns: 2, location: %{index: 10}}},
      %{insert_inline_image: %{uri: "https://example.com/img.png", location: %{index: 20}}}
    ]

    assert :ok = BatchUpdateRequest.validate_requests(requests)
  end

  test "batch update request validate_requests rejects empty list" do
    assert {:error, :empty_requests} = BatchUpdateRequest.validate_requests([])
  end

  test "batch update request validate_requests rejects too many requests" do
    requests = Enum.map(1..101, fn i -> %{insert_text: %{text: "#{i}"}} end)

    assert {:error, {:too_many_requests, 101, 100}} =
             BatchUpdateRequest.validate_requests(requests)
  end

  test "batch update request validate_requests rejects multi-key maps" do
    assert {:error, {:invalid_request, 0, "must contain exactly one operation"}} =
             BatchUpdateRequest.validate_requests([%{insert_text: %{}, update_text_style: %{}}])
  end

  test "batch update request validate_requests rejects unsupported operations" do
    assert {:error, {:unsupported_operation, 0, :dangerous_op}} =
             BatchUpdateRequest.validate_requests([%{dangerous_op: %{}}])
  end

  test "batch update request validate_requests rejects non-list" do
    assert {:error, :not_a_list} = BatchUpdateRequest.validate_requests("not a list")
  end

  test "batch update request validate_requests rejects non-map entries" do
    assert {:error, {:invalid_request, 0, "must be a map"}} =
             BatchUpdateRequest.validate_requests(["not a map"])
  end

  test "batch update request supported_operations includes expected operations" do
    ops = BatchUpdateRequest.supported_operations()

    assert MapSet.member?(ops, "insert_text")
    assert MapSet.member?(ops, "update_text_style")
    assert MapSet.member?(ops, "insert_table")
    assert MapSet.member?(ops, "insert_inline_image")
    assert MapSet.member?(ops, "delete_content_range")
    assert MapSet.member?(ops, "replace_all_text")
    assert MapSet.member?(ops, "update_paragraph_style")
    assert MapSet.member?(ops, "update_table_cell_style")
  end

  test "batch update request max_requests returns limit" do
    assert BatchUpdateRequest.max_requests() == 100
  end
end
