defmodule Jido.Connect.Google.Forms.Normalizer do
  @moduledoc "Normalizes Google Forms API payloads into stable package structs."

  alias Jido.Connect.Data

  alias Jido.Connect.Google.Forms.{
    BatchUpdateResult,
    Form,
    QuestionItem,
    Response,
    Watch
  }

  @question_type_mapping %{
    "textQuestion" => "text",
    "textParagraphQuestion" => "text_paragraph",
    "multipleChoiceQuestion" => "multiple_choice",
    "checkboxQuestion" => "checkbox",
    "dropdownQuestion" => "dropdown",
    "scaleQuestion" => "scale",
    "dateQuestion" => "date",
    "timeQuestion" => "time",
    "durationQuestion" => "duration",
    "fileUploadQuestion" => "file_upload",
    "rowQuestion" => "row_question",
    "gridQuestion" => "grid"
  }

  @doc "Normalizes a Google Forms form payload."
  @spec form(map()) :: {:ok, Form.t()} | {:error, term()}
  def form(payload) when is_map(payload) do
    form_info = Data.get(payload, "formInfo", %{}) || %{}

    linked_sheet_id =
      case Data.get(payload, "linkedSheetId") do
        nil -> Data.get(payload, "linkedSheetId")
        id -> id
      end

    %{
      form_id: Data.get(payload, "formId"),
      title: Data.get(form_info, "title"),
      description: Data.get(form_info, "description"),
      form_url: Data.get(payload, "responderUri"),
      editor_file_url: Data.get(payload, "editorFileUri"),
      revision_id: Data.get(payload, "revisionId"),
      linked_sheet_id: linked_sheet_id,
      published: Data.get(payload, "published"),
      items: payload |> Data.get("items", []) |> Enum.map(&question_item!/1)
    }
    |> Data.compact()
    |> Form.new()
  end

  @doc "Normalizes a Google Forms item/question payload."
  @spec question_item(map()) :: {:ok, QuestionItem.t()} | {:error, term()}
  def question_item(payload) when is_map(payload) do
    {question_type, question_id, question_details} = extract_question(payload)

    %{
      item_id: Data.get(payload, "itemId"),
      title: Data.get(payload, "title"),
      description: Data.get(payload, "description"),
      image: Data.get(payload, "image"),
      video: Data.get(payload, "video"),
      question_type: question_type,
      question_id: question_id,
      required:
        Data.get(payload, "questionItem", %{})
        |> Data.get("question", %{})
        |> Data.get("required"),
      question_details: question_details
    }
    |> Data.compact()
    |> QuestionItem.new()
  end

  @doc "Normalizes a Google Forms response payload."
  @spec response(map()) :: {:ok, Response.t()} | {:error, term()}
  def response(payload) when is_map(payload) do
    answers =
      payload
      |> Data.get("answers", %{})
      |> case do
        answers when is_map(answers) ->
          answers
          |> Enum.map(fn {question_id, answer} ->
            normalize_answer(question_id, answer)
          end)

        answers when is_list(answers) ->
          Enum.map(answers, &normalize_answer_entry/1)

        _ ->
          []
      end

    %{
      response_id: Data.get(payload, "responseId"),
      form_id: Data.get(payload, "formId"),
      respondent_email: Data.get(payload, "respondentEmail"),
      create_time: Data.get(payload, "createTime"),
      last_submitted_time: Data.get(payload, "lastSubmittedTime"),
      total_score: Data.get(payload, "totalScore"),
      answers: answers
    }
    |> Data.compact()
    |> Response.new()
  end

  @doc "Normalizes a Google Forms watch payload."
  @spec watch(map()) :: {:ok, Watch.t()} | {:error, term()}
  def watch(payload) when is_map(payload) do
    %{
      watch_id: Data.get(payload, "id"),
      target_id: Data.get(payload, "targetId"),
      state: Data.get(payload, "state"),
      event_type: Data.get(payload, "eventType"),
      error_type: Data.get(payload, "errorType"),
      create_time: Data.get(payload, "createTime"),
      expire_time: Data.get(payload, "expireTime")
    }
    |> Data.compact()
    |> Watch.new()
  end

  @doc "Normalizes a Google Forms batch update result payload."
  @spec batch_update_result(map()) :: {:ok, BatchUpdateResult.t()} | {:error, term()}
  def batch_update_result(payload) when is_map(payload) do
    form_result =
      case Data.get(payload, "form") do
        nil -> nil
        form_payload -> form(form_payload)
      end

    result = %{
      form_id: Data.get(payload, "formId"),
      replies: payload |> Data.get("replies", []) |> Enum.map(&public_map/1),
      write_control: Data.get(payload, "writeControl")
    }

    result =
      case form_result do
        {:ok, form} -> Map.put(result, :form, public_map(form))
        _ -> result
      end

    result
    |> Data.compact()
    |> BatchUpdateResult.new()
  end

  defp extract_question(payload) do
    question_item = Data.get(payload, "questionItem", %{}) || %{}
    question = Data.get(question_item, "question", %{}) || %{}

    question_type =
      question
      |> Map.keys()
      |> Enum.find(&Map.has_key?(@question_type_mapping, &1))
      |> then(fn key -> Map.get(@question_type_mapping, key) end)

    question_id = Data.get(question, "questionId")

    question_details =
      question
      |> Map.drop(["questionId"])
      |> (fn details ->
            if map_size(details) > 0, do: details, else: nil
          end).()

    {question_type, question_id, question_details}
  end

  defp normalize_answer(question_id, answer) when is_map(answer) do
    %{
      question_id: question_id,
      text_answers: answer |> Data.get("textAnswers", %{}) |> Data.get("answers", []),
      file_upload_answers:
        answer |> Data.get("fileUploadAnswers", %{}) |> Data.get("answers", []),
      grade: answer |> Data.get("grade")
    }
    |> Data.compact()
  end

  defp normalize_answer(_question_id, _answer), do: %{}

  defp normalize_answer_entry(entry) when is_map(entry) do
    Data.get(entry, "questionId")
    |> normalize_answer(entry)
  end

  defp normalize_answer_entry(_entry), do: %{}

  defp question_item!(payload) do
    case question_item(payload) do
      {:ok, item} -> item
      {:error, error} -> raise error
    end
  end

  defp public_map(struct) when is_struct(struct),
    do: struct |> Map.from_struct() |> public_map()

  defp public_map(map) when is_map(map) do
    map
    |> Map.new(fn {key, value} -> {key, public_map(value)} end)
  end

  defp public_map(list) when is_list(list), do: Enum.map(list, &public_map/1)
  defp public_map(value), do: value
end
