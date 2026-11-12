defmodule Jido.Connect.Gmail.Handlers.Actions.Content do
  @moduledoc false

  # Builds MessageContent and ThreadContent from Gmail format=full resources
  # for the content actions. A text part that Gmail stores behind an
  # attachmentId is fetched with the gmail_client's get_attachment/2, one
  # request per part, and decoded by the MIME traversal. File attachments are
  # never fetched. A failed fetch fails the whole read.

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Gmail.{MessageContent, Normalizer, ThreadContent}
  alias Jido.Connect.Gmail.MIME.Traversal

  # The input default of google.gmail.thread.content.get.
  @default_max_messages 100

  @named_headers [
    from: "from",
    to: "to",
    cc: "cc",
    bcc: "bcc",
    reply_to: "reply-to",
    subject: "subject",
    date: "date",
    rfc_message_id: "message-id",
    in_reply_to: "in-reply-to",
    references: "references"
  ]

  @doc "Reads `max_messages` from the action input."
  def max_messages(input) do
    case Data.get(input, :max_messages) do
      nil ->
        {:ok, @default_max_messages}

      max when is_integer(max) and max >= 1 ->
        {:ok, max}

      _invalid ->
        {:error,
         Error.validation("Gmail max_messages must be an integer of at least 1",
           reason: :invalid_max_messages,
           details: %{field: :max_messages}
         )}
    end
  end

  @doc "Builds the content of a Gmail `format=full` message resource."
  def message(resource, client, access_token) when is_map(resource) do
    with {:ok, message_id} <- resource_id(resource),
         {:ok, traversal} <- Traversal.traverse(Data.get(resource, "payload")),
         {:ok, content} <-
           resolve(traversal, &fetch_text_part(client, access_token, message_id, &1)) do
      resource
      |> message_attrs(message_id, content)
      |> MessageContent.new()
      |> struct_result(%{message_id: message_id})
    end
  end

  def message(_resource, _client, _access_token), do: invalid_response(%{})

  @doc """
  Builds the content of a Gmail `format=full` thread resource with at most
  `max_messages` messages, ordered by numeric `internalDate`.
  """
  def thread(resource, client, access_token, max_messages) when is_map(resource) do
    with {:ok, thread_id} <- resource_id(resource),
         {:ok, messages} <- thread_messages(resource, thread_id),
         :ok <- within_max_messages(messages, max_messages, thread_id),
         {:ok, messages} <- order_by_internal_date(messages),
         {:ok, contents} <- map_ok(messages, &message(&1, client, access_token)) do
      %{
        thread_id: thread_id,
        history_id: string(Data.get(resource, "historyId")),
        messages: contents
      }
      |> ThreadContent.new()
      |> struct_result(%{thread_id: thread_id})
    end
  end

  def thread(_resource, _client, _access_token, _max_messages), do: invalid_response(%{})

  defp resolve(content, fetch) do
    with {:ok, fetched} <- map_ok(content.external_text_parts, fetch),
         {:ok, messages} <- map_ok(content.messages, &resolve_message(&1, fetch)) do
      {:ok,
       %{
         text_parts: Enum.sort_by(content.text_parts ++ fetched, &part_order(&1.part_id)),
         attachments: content.attachments,
         messages: messages
       }}
    end
  end

  defp resolve_message(message, fetch) do
    with {:ok, resolved} <- resolve(message, fetch) do
      {:ok, message |> Map.delete(:external_text_parts) |> Map.merge(resolved)}
    end
  end

  defp fetch_text_part(client, access_token, message_id, part) do
    params = %{message_id: message_id, attachment_id: part.attachment_id}

    with {:ok, attachment} <- client.get_attachment(params, access_token) do
      case attachment do
        %{data: data} when is_binary(data) ->
          Traversal.decode_external_text_part(part, data)

        _no_data ->
          invalid_response(%{message_id: message_id, part_id: part.part_id})
      end
    end
  end

  # Gmail numbers parts "0", "0.1", "0.10"; comparing the segments as integers
  # keeps "0.2" before "0.10".
  defp part_order(part_id) when is_binary(part_id) do
    part_id
    |> String.split(".", trim: true)
    |> Enum.map(fn segment ->
      case Integer.parse(segment) do
        {number, ""} -> number
        _other -> segment
      end
    end)
  end

  defp part_order(_part_id), do: []

  defp message_attrs(resource, message_id, content) do
    headers =
      resource
      |> Data.get("payload", %{})
      |> Data.get("headers", [])
      |> Normalizer.normalize_headers()

    %{
      message_id: message_id,
      thread_id: Data.get(resource, "threadId"),
      history_id: string(Data.get(resource, "historyId")),
      label_ids: Data.get(resource, "labelIds", []),
      internal_date: string(Data.get(resource, "internalDate")),
      headers: headers
    }
    |> Map.merge(Map.new(@named_headers, fn {field, name} -> {field, header(headers, name)} end))
    |> Map.merge(content)
  end

  defp header(headers, name) do
    Enum.find_value(headers, fn header ->
      if String.downcase(header.name) == name, do: header.value
    end)
  end

  defp resource_id(resource) do
    case Data.get(resource, "id") do
      id when is_binary(id) and id != "" -> {:ok, id}
      _missing -> invalid_response(%{})
    end
  end

  defp thread_messages(resource, thread_id) do
    case Data.get(resource, "messages", []) do
      messages when is_list(messages) ->
        if Enum.all?(messages, &is_map/1),
          do: {:ok, messages},
          else: invalid_response(%{thread_id: thread_id})

      _invalid ->
        invalid_response(%{thread_id: thread_id})
    end
  end

  defp within_max_messages(messages, max_messages, thread_id) do
    if length(messages) <= max_messages do
      :ok
    else
      {:error,
       Error.provider("Gmail thread exceeds max_messages",
         provider: :google,
         reason: :thread_messages_exceeded,
         details: %{
           thread_id: thread_id,
           max_messages: max_messages,
           message_count: length(messages)
         }
       )}
    end
  end

  # Enum.sort_by/2 is stable, so messages with the same internalDate keep
  # Gmail's order.
  defp order_by_internal_date(messages) do
    with {:ok, keyed} <- map_ok(messages, &internal_date_key/1) do
      {:ok, keyed |> Enum.sort_by(&elem(&1, 0)) |> Enum.map(&elem(&1, 1))}
    end
  end

  defp internal_date_key(message) do
    case Data.get(message, "internalDate") do
      date when is_integer(date) ->
        {:ok, {date, message}}

      date when is_binary(date) ->
        case Integer.parse(date) do
          {number, ""} -> {:ok, {number, message}}
          _invalid -> invalid_response(%{message_id: Data.get(message, "id")})
        end

      _missing ->
        invalid_response(%{message_id: Data.get(message, "id")})
    end
  end

  defp map_ok(items, fun) do
    items
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
      case fun.(item) do
        {:ok, value} -> {:cont, {:ok, [value | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      {:error, error} -> {:error, error}
    end
  end

  defp struct_result({:ok, struct}, _details), do: {:ok, struct}
  defp struct_result({:error, _errors}, details), do: invalid_response(details)

  # Details name IDs only, never message data.
  defp invalid_response(details) do
    {:error,
     Error.provider("Gmail content response was invalid",
       provider: :google,
       reason: :invalid_response,
       details: details
     )}
  end

  # Gmail sends historyId and internalDate as strings. An integer becomes one;
  # any other value stays as it is, so the struct schema rejects it.
  defp string(value) when is_integer(value), do: Integer.to_string(value)
  defp string(value), do: value
end
