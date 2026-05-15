defmodule Jido.Connect.Google.Forms.StructTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Forms.{
    BatchUpdateResult,
    Form,
    QuestionItem,
    Response,
    Watch
  }

  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "form struct validates with Zoi" do
    form =
      ConnectorContracts.assert_struct_defaults(
        Form,
        %{form_id: "1ABCdefGHI"},
        items: [],
        metadata: %{}
      )

    assert form.form_id == "1ABCdefGHI"
    assert {:error, _error} = Form.new(%{})
  end

  test "form struct accepts full attributes" do
    form =
      Form.new!(%{
        form_id: "1ABCdefGHI",
        title: "Customer Survey",
        description: "Tell us what you think.",
        form_url: "https://docs.google.com/forms/d/e/1ABC/viewform",
        editor_file_url: "https://docs.google.com/forms/d/1ABC/edit",
        revision_id: "rev001",
        linked_sheet_id: "1SPREADSHEET",
        published: true,
        items: []
      })

    assert form.title == "Customer Survey"
    assert form.description == "Tell us what you think."
    assert form.form_url == "https://docs.google.com/forms/d/e/1ABC/viewform"
    assert form.editor_file_url == "https://docs.google.com/forms/d/1ABC/edit"
    assert form.revision_id == "rev001"
    assert form.linked_sheet_id == "1SPREADSHEET"
    assert form.published == true
  end

  test "question item struct validates with Zoi" do
    item =
      ConnectorContracts.assert_struct_defaults(
        QuestionItem,
        %{item_id: "item_001", question_type: "multiple_choice"},
        metadata: %{}
      )

    assert item.item_id == "item_001"
    assert item.question_type == "multiple_choice"
  end

  test "question item struct accepts empty optional fields" do
    item = QuestionItem.new!(%{})
    assert item.metadata == %{}
  end

  test "question item struct accepts all optional fields" do
    item =
      QuestionItem.new!(%{
        item_id: "item_002",
        title: "Your name?",
        description: "Enter your full name.",
        question_type: "text",
        question_id: "question_002",
        required: false,
        question_details: %{"paragraph" => false}
      })

    assert item.title == "Your name?"
    assert item.description == "Enter your full name."
    assert item.question_type == "text"
    assert item.question_id == "question_002"
    assert item.required == false
    assert item.question_details == %{"paragraph" => false}
  end

  test "response struct validates with Zoi" do
    response =
      ConnectorContracts.assert_struct_defaults(
        Response,
        %{response_id: "resp_001"},
        answers: [],
        metadata: %{}
      )

    assert response.response_id == "resp_001"
  end

  test "response struct accepts empty optional fields" do
    response = Response.new!(%{})
    assert response.answers == []
    assert response.metadata == %{}
  end

  test "response struct accepts all optional fields" do
    response =
      Response.new!(%{
        response_id: "resp_002",
        form_id: "1ABCdefGHI",
        respondent_email: "user@example.com",
        create_time: "2026-05-14T10:00:00.000Z",
        last_submitted_time: "2026-05-14T10:02:30.000Z",
        total_score: 8.5,
        answers: [%{question_id: "q1", text_answers: [%{value: "Yes"}]}]
      })

    assert response.form_id == "1ABCdefGHI"
    assert response.respondent_email == "user@example.com"
    assert response.create_time == "2026-05-14T10:00:00.000Z"
    assert response.last_submitted_time == "2026-05-14T10:02:30.000Z"
    assert response.total_score == 8.5
    assert length(response.answers) == 1
  end

  test "watch struct validates with Zoi" do
    watch =
      ConnectorContracts.assert_struct_defaults(
        Watch,
        %{watch_id: "watch_001"},
        metadata: %{}
      )

    assert watch.watch_id == "watch_001"
  end

  test "watch struct accepts empty optional fields" do
    watch = Watch.new!(%{})
    assert watch.metadata == %{}
  end

  test "watch struct accepts all optional fields" do
    watch =
      Watch.new!(%{
        watch_id: "watch_abc",
        target_id: "1ABCdefGHI",
        state: "ACTIVE",
        event_type: "RESPONSE",
        error_type: nil,
        create_time: "2026-05-14T12:00:00.000Z",
        expire_time: "2026-05-21T12:00:00.000Z"
      })

    assert watch.target_id == "1ABCdefGHI"
    assert watch.state == "ACTIVE"
    assert watch.event_type == "RESPONSE"
    assert watch.create_time == "2026-05-14T12:00:00.000Z"
    assert watch.expire_time == "2026-05-21T12:00:00.000Z"
  end

  test "batch update result struct validates with Zoi" do
    result =
      ConnectorContracts.assert_struct_defaults(
        BatchUpdateResult,
        %{form_id: "1ABCdefGHI"},
        replies: [],
        metadata: %{}
      )

    assert result.form_id == "1ABCdefGHI"
    assert result.replies == []
  end

  test "batch update result struct accepts all optional fields" do
    result =
      BatchUpdateResult.new!(%{
        form_id: "1ABCdefGHI",
        replies: [%{"createItem" => %{"itemId" => "new_1"}}],
        write_control: %{"requiredRevisionId" => "rev002"}
      })

    assert length(result.replies) == 1
    assert result.write_control == %{"requiredRevisionId" => "rev002"}
  end
end
