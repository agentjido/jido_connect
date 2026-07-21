defmodule Jido.Connect.Google.Forms.FixtureTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Forms.Normalizer

  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  test "normalizes common Google Forms form fixture" do
    payload = fixture!("form_common.json")

    assert {:ok, form} = Normalizer.form(payload)
    assert form.form_id == "1ABCdefGHIjklMNO_pqrSTU_vwx_YZ"
    assert form.title == "Customer Satisfaction Survey"
    assert form.description == "Please share your experience with our service."
    assert form.revision_id == "000001"
    assert form.form_url =~ "viewform"
    assert form.editor_file_url =~ "edit"
    assert form.linked_sheet_id == "1SPREADSHEET_ID_abc123"
    assert form.published == true
    assert length(form.items) == 3
  end

  test "normalizes form fixture items and question types" do
    payload = fixture!("form_common.json")

    assert {:ok, form} = Normalizer.form(payload)
    [item1, item2, item3] = form.items

    assert item1.item_id == "item_001"
    assert item1.title == "How satisfied are you with our service?"
    assert item1.question_type == "multiple_choice"
    assert item1.question_id == "question_001"
    assert item1.required == true
    assert item1.question_details != nil

    assert item2.item_id == "item_002"
    assert item2.title == "What could we improve?"
    assert item2.description == "Please provide any additional feedback."
    assert item2.question_type == "text"
    assert item2.question_id == "question_002"
    assert item2.required == false

    assert item3.item_id == "item_003"
    assert item3.title == "Would you recommend us to a friend?"
    assert item3.question_type == "scale"
    assert item3.question_id == "question_003"
    assert item3.required == true
  end

  test "normalizes minimal Google Forms form fixture" do
    payload = fixture!("form_minimal.json")

    assert {:ok, form} = Normalizer.form(payload)
    assert form.form_id == "1MINIMAL_form_id_456"
    assert form.title == "Quick Poll"
    assert form.revision_id == "000002"
    assert form.description == nil
    assert form.items == []
    assert form.form_url == nil
    assert form.linked_sheet_id == nil
  end

  test "normalizes Google Forms response fixture" do
    payload = fixture!("response_common.json")

    assert {:ok, response} = Normalizer.response(payload)
    assert response.response_id == "ACYDBNhW5dYSnRJ8xVBM3yMFvYgzbA5v4VpZGhKB6YxHWDiNeCgtMNvJ8w"
    assert response.form_id == "1ABCdefGHIjklMNO_pqrSTU_vwx_YZ"
    assert response.respondent_email == "user@example.com"
    assert response.create_time == "2026-05-14T10:00:00.000Z"
    assert response.last_submitted_time == "2026-05-14T10:02:30.000Z"
    assert length(response.answers) == 3
  end

  test "normalizes response fixture answers" do
    payload = fixture!("response_common.json")

    assert {:ok, response} = Normalizer.response(payload)
    [answer1, answer2, answer3] = response.answers

    assert answer1.question_id == "question_001"
    assert answer1.text_answers != nil

    assert answer2.question_id == "question_002"
    assert answer2.text_answers != nil

    assert answer3.question_id == "question_003"
    assert answer3.text_answers != nil
  end

  test "normalizes Google Forms watch fixture" do
    payload = fixture!("watch_common.json")

    assert {:ok, watch} = Normalizer.watch(payload)
    assert watch.watch_id == "watch_abc123"
    assert watch.target_id == "1ABCdefGHIjklMNO_pqrSTU_vwx_YZ"
    assert watch.state == "ACTIVE"
    assert watch.event_type == "RESPONSE"
    assert watch.create_time == "2026-05-14T12:00:00.000Z"
    assert watch.expire_time == "2026-05-21T12:00:00.000Z"
  end

  test "normalizes Google Forms batch update result fixture" do
    payload = fixture!("batch_update_result.json")

    assert {:ok, result} = Normalizer.batch_update_result(payload)
    assert result.form_id == "1ABCdefGHIjklMNO_pqrSTU_vwx_YZ"
    assert length(result.replies) == 2
    assert result.write_control != nil
  end

  test "normalizes question item directly" do
    payload = %{
      "itemId" => "item_direct",
      "title" => "Pick one",
      "questionItem" => %{
        "question" => %{
          "questionId" => "q_direct",
          "required" => true,
          "dropdownQuestion" => %{
            "options" => [%{"value" => "A"}, %{"value" => "B"}]
          }
        }
      }
    }

    assert {:ok, item} = Normalizer.question_item(payload)
    assert item.item_id == "item_direct"
    assert item.title == "Pick one"
    assert item.question_type == "dropdown"
    assert item.question_id == "q_direct"
    assert item.required == true
    assert item.question_details != nil
  end

  test "normalizes question item with image" do
    payload = %{
      "itemId" => "item_img",
      "title" => "Rate this image",
      "image" => %{
        "contentUri" => "https://example.com/img.png",
        "altText" => "Sample image"
      }
    }

    assert {:ok, item} = Normalizer.question_item(payload)
    assert item.item_id == "item_img"
    assert item.image != nil
  end

  test "normalizes response with empty answers" do
    payload = %{
      "responseId" => "resp_empty",
      "formId" => "1XYZ",
      "answers" => %{}
    }

    assert {:ok, response} = Normalizer.response(payload)
    assert response.response_id == "resp_empty"
    assert response.answers == []
  end

  test "normalizes batch update result with empty replies" do
    payload = %{
      "formId" => "1XYZ_empty",
      "replies" => []
    }

    assert {:ok, result} = Normalizer.batch_update_result(payload)
    assert result.form_id == "1XYZ_empty"
    assert result.replies == []
  end

  test "normalizes Google Forms response list fixture" do
    payload = fixture!("response_list.json")

    assert {:ok, responses} =
             payload
             |> Map.get("responses")
             |> Enum.map(&Normalizer.response/1)
             |> Enum.reduce_while({:ok, []}, fn
               {:ok, r}, {:ok, acc} -> {:cont, {:ok, [r | acc]}}
               {:error, e}, _ -> {:halt, {:error, e}}
             end)
             |> then(fn
               {:ok, items} -> {:ok, Enum.reverse(items)}
               {:error, e} -> {:error, e}
             end)

    assert length(responses) == 2
    [resp1, resp2] = responses
    assert resp1.response_id == "ACYDBNhW5dYSnRJ8xVBM3yMFvYgzbA5v4VpZGhKB6YxHWDiNeCgtMNvJ8w"
    assert resp1.respondent_email == "user@example.com"
    assert resp2.response_id == "ACYDBNhAnotherResponseId"
    assert resp2.respondent_email == "other@example.com"
  end

  defp fixture!(name) do
    ConnectorContracts.google_fixture!(:google_forms, name, __DIR__)
  end
end
