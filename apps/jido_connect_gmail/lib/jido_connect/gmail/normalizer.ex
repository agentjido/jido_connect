defmodule Jido.Connect.Gmail.Normalizer do
  @moduledoc "Normalizes Gmail API payloads into stable, body-safe package structs."

  alias Jido.Connect.Data
  alias Jido.Connect.Gmail.{Attachment, Draft, Label, Message, Privacy, Profile, Thread, Watch}

  @doc "Normalizes a Gmail profile payload."
  @spec profile(map()) :: {:ok, Profile.t()} | {:error, term()}
  def profile(payload) when is_map(payload) do
    %{
      email_address: Data.get(payload, "emailAddress"),
      messages_total: normalize_integer(Data.get(payload, "messagesTotal")),
      threads_total: normalize_integer(Data.get(payload, "threadsTotal")),
      history_id: normalize_string(Data.get(payload, "historyId"))
    }
    |> Data.compact()
    |> Profile.new()
  end

  def profile(_payload), do: {:error, :invalid_profile_payload}

  @doc "Normalizes a Gmail label payload."
  @spec label(map()) :: {:ok, Label.t()} | {:error, term()}
  def label(payload) when is_map(payload) do
    %{
      label_id: Data.get(payload, "id"),
      name: Data.get(payload, "name"),
      type: Data.get(payload, "type"),
      message_list_visibility: Data.get(payload, "messageListVisibility"),
      label_list_visibility: Data.get(payload, "labelListVisibility"),
      messages_total: normalize_integer(Data.get(payload, "messagesTotal")),
      messages_unread: normalize_integer(Data.get(payload, "messagesUnread")),
      threads_total: normalize_integer(Data.get(payload, "threadsTotal")),
      threads_unread: normalize_integer(Data.get(payload, "threadsUnread")),
      color: Data.get(payload, "color", %{})
    }
    |> Data.compact()
    |> Label.new()
  end

  def label(_payload), do: {:error, :invalid_label_payload}

  @doc "Normalizes a Gmail message payload without raw body leakage."
  @spec message(map()) :: {:ok, Message.t()} | {:error, term()}
  def message(payload) when is_map(payload) do
    gmail_payload = Data.get(payload, "payload", %{})

    %{
      message_id: Data.get(payload, "id"),
      thread_id: Data.get(payload, "threadId"),
      label_ids: Data.get(payload, "labelIds", []),
      snippet: Data.get(payload, "snippet"),
      history_id: normalize_string(Data.get(payload, "historyId")),
      internal_date: normalize_string(Data.get(payload, "internalDate")),
      size_estimate: normalize_integer(Data.get(payload, "sizeEstimate")),
      headers: normalize_headers(Data.get(gmail_payload, "headers", [])),
      payload_summary: summarize_payload(gmail_payload)
    }
    |> Data.compact()
    |> Message.new()
  end

  def message(_payload), do: {:error, :invalid_message_payload}

  @doc "Normalizes a Gmail thread payload with sanitized messages."
  @spec thread(map()) :: {:ok, Thread.t()} | {:error, term()}
  def thread(payload) when is_map(payload) do
    with {:ok, messages} <- normalize_messages(Data.get(payload, "messages", [])) do
      %{
        thread_id: Data.get(payload, "id"),
        history_id: normalize_string(Data.get(payload, "historyId")),
        snippet: thread_snippet(messages),
        messages: messages
      }
      |> Data.compact()
      |> Thread.new()
    end
  end

  def thread(_payload), do: {:error, :invalid_thread_payload}

  @doc "Normalizes a Gmail draft payload with a sanitized message."
  @spec draft(map()) :: {:ok, Draft.t()} | {:error, term()}
  def draft(payload) when is_map(payload) do
    with {:ok, message} <- normalize_draft_message(Data.get(payload, "message")) do
      %{
        draft_id: Data.get(payload, "id"),
        message: message
      }
      |> Data.compact()
      |> Draft.new()
    end
  end

  def draft(_payload), do: {:error, :invalid_draft_payload}

  @doc "Normalizes a Gmail watch response."
  @spec watch(map()) :: {:ok, Watch.t()} | {:error, term()}
  def watch(payload) when is_map(payload) do
    %{
      history_id: normalize_string(Data.get(payload, "historyId")),
      expiration: normalize_string(Data.get(payload, "expiration"))
    }
    |> Data.compact()
    |> Watch.new()
  end

  def watch(_payload), do: {:error, :invalid_watch_payload}

  @doc "Normalizes a Gmail message attachment response."
  @spec attachment(map()) :: {:ok, Attachment.t()} | {:error, term()}
  def attachment(payload) when is_map(payload) do
    %{
      attachment_id: Data.get(payload, "attachmentId"),
      size: normalize_integer(Data.get(payload, "size")),
      data: Data.get(payload, "data")
    }
    |> Data.compact()
    |> Attachment.new()
  end

  def attachment(_payload), do: {:error, :invalid_attachment_payload}

  @doc "Builds a body-safe summary of a Gmail MIME payload."
  def summarize_payload(payload) when is_map(payload) do
    %{
      part_id: Data.get(payload, "partId"),
      mime_type: Data.get(payload, "mimeType"),
      filename: Data.get(payload, "filename"),
      body_size: payload |> Data.get("body", %{}) |> Data.get("size") |> normalize_integer(),
      headers: normalize_headers(Data.get(payload, "headers", [])),
      parts: payload |> Data.get("parts", []) |> summarize_parts()
    }
    |> Data.compact()
    |> reject_raw_body_keys()
  end

  def summarize_payload(_payload), do: %{}

  @doc "Normalizes Gmail header payloads to `%{name:, value:}` maps."
  def normalize_headers(headers) when is_list(headers) do
    headers
    |> Enum.flat_map(fn
      %{} = header ->
        case {Data.get(header, "name"), Data.get(header, "value")} do
          {name, value} when is_binary(name) and is_binary(value) -> [%{name: name, value: value}]
          _other -> []
        end

      _other ->
        []
    end)
  end

  def normalize_headers(_headers), do: []

  @doc "Removes raw body-bearing keys from a map."
  def reject_raw_body_keys(map) when is_map(map) do
    map
    |> Enum.reject(fn {key, _value} -> Privacy.raw_body_key?(key) end)
    |> Map.new()
  end

  defp normalize_messages(messages) when is_list(messages) do
    Enum.reduce_while(messages, {:ok, []}, fn payload, {:ok, acc} ->
      case message(payload) do
        {:ok, message} -> {:cont, {:ok, [message | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, messages} -> {:ok, Enum.reverse(messages)}
      {:error, error} -> {:error, error}
    end
  end

  defp normalize_messages(_messages), do: {:error, :invalid_messages}

  defp normalize_draft_message(%{} = payload), do: message(payload)
  defp normalize_draft_message(_payload), do: {:ok, nil}

  defp summarize_parts(parts) when is_list(parts), do: Enum.map(parts, &summarize_payload/1)
  defp summarize_parts(_parts), do: []

  defp thread_snippet([%Message{snippet: snippet} | _rest]), do: snippet
  defp thread_snippet(_messages), do: nil

  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _other -> nil
    end
  end

  defp normalize_integer(_value), do: nil

  defp normalize_string(nil), do: nil
  defp normalize_string(value) when is_binary(value), do: value
  defp normalize_string(value), do: to_string(value)
end
