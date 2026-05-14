defmodule Jido.Connect.Google.Meet.Client.Response do
  @moduledoc "Google Meet response handling."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.Meet.{Client.Transport, Normalizer}

  def handle_space_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.space/1, "Google Meet space response was invalid")
  end

  def handle_space_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Meet space response was invalid", body)
  end

  def handle_space_response(response), do: Transport.handle_error_response(response)

  def handle_conference_record_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, conference_records} <-
           normalize_items(
             body,
             "conferenceRecords",
             &Normalizer.conference_record/1,
             "Google Meet conference record list response was invalid"
           ) do
      {:ok,
       %{
         conference_records: conference_records,
         next_page_token: Data.get(body, "nextPageToken")
       }
       |> Data.compact()}
    end
  end

  def handle_conference_record_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response(
      "Google Meet conference record list response was invalid",
      body
    )
  end

  def handle_conference_record_list_response(response),
    do: Transport.handle_error_response(response)

  def handle_conference_record_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(
      body,
      &Normalizer.conference_record/1,
      "Google Meet conference record response was invalid"
    )
  end

  def handle_conference_record_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Meet conference record response was invalid", body)
  end

  def handle_conference_record_response(response), do: Transport.handle_error_response(response)

  def handle_recording_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, recordings} <-
           normalize_items(
             body,
             "recordings",
             &Normalizer.recording/1,
             "Google Meet recording list response was invalid"
           ) do
      {:ok,
       %{
         recordings: recordings,
         next_page_token: Data.get(body, "nextPageToken")
       }
       |> Data.compact()}
    end
  end

  def handle_recording_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Meet recording list response was invalid", body)
  end

  def handle_recording_list_response(response), do: Transport.handle_error_response(response)

  def handle_recording_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.recording/1, "Google Meet recording response was invalid")
  end

  def handle_recording_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Meet recording response was invalid", body)
  end

  def handle_recording_response(response), do: Transport.handle_error_response(response)

  def handle_transcript_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, transcripts} <-
           normalize_items(
             body,
             "transcripts",
             &Normalizer.transcript/1,
             "Google Meet transcript list response was invalid"
           ) do
      {:ok,
       %{
         transcripts: transcripts,
         next_page_token: Data.get(body, "nextPageToken")
       }
       |> Data.compact()}
    end
  end

  def handle_transcript_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Meet transcript list response was invalid", body)
  end

  def handle_transcript_list_response(response), do: Transport.handle_error_response(response)

  def handle_transcript_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.transcript/1, "Google Meet transcript response was invalid")
  end

  def handle_transcript_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Meet transcript response was invalid", body)
  end

  def handle_transcript_response(response), do: Transport.handle_error_response(response)

  defp normalize_one(body, normalizer, message) do
    case normalizer.(body) do
      {:ok, item} -> {:ok, item}
      {:error, _error} -> Transport.invalid_success_response(message, body)
    end
  end

  defp normalize_items(body, key, normalizer, message) do
    case Data.get(body, key, []) do
      items when is_list(items) ->
        items
        |> Enum.reduce_while({:ok, []}, fn payload, {:ok, acc} ->
          case normalizer.(payload) do
            {:ok, item} -> {:cont, {:ok, [item | acc]}}
            {:error, _error} -> {:halt, Transport.invalid_success_response(message, body)}
          end
        end)
        |> case do
          {:ok, items} -> {:ok, Enum.reverse(items)}
          {:error, error} -> {:error, error}
        end

      _invalid ->
        Transport.invalid_success_response(message, body)
    end
  end
end
