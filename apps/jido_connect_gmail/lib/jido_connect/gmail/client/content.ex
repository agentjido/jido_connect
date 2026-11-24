defmodule Jido.Connect.Gmail.Client.Content do
  @moduledoc """
  Gmail message, thread and attachment content requests.

  Each request asks for Gmail's `format=full` representation, which carries
  every MIME part with its headers and the body data that Gmail keeps inline.
  The message and thread requests return the decoded Gmail resource
  unchanged. The content actions walk it with
  `Jido.Connect.Gmail.MIME.Traversal`, fetch text parts stored behind an
  `attachmentId` with `get_attachment/2` and build the content structs.

  `get_attachment_content/2` selects one attachment of the message by Gmail
  `partId` and returns a `Jido.Connect.Gmail.AttachmentContent`.
  """

  alias Jido.Connect.{Data, Error, Http}
  alias Jido.Connect.Gmail.AttachmentContent
  alias Jido.Connect.Gmail.Client.{Transport, Users}
  alias Jido.Connect.Gmail.MIME.Traversal

  @full_params [format: "full"]

  @doc "Gets a message in `format=full`."
  def get_message_content(%{message_id: message_id}, access_token)
      when is_binary(message_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url:
        Http.url_with_query(
          "/gmail/v1/users/me/messages/#{encode_path_segment(message_id)}",
          @full_params
        )
    )
    |> handle_response("Gmail message content response was invalid")
  end

  @doc "Gets a thread with all its messages in `format=full`."
  def get_thread_content(%{thread_id: thread_id}, access_token)
      when is_binary(thread_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url:
        Http.url_with_query(
          "/gmail/v1/users/me/threads/#{encode_path_segment(thread_id)}",
          @full_params
        )
    )
    |> handle_response("Gmail thread content response was invalid")
  end

  @doc """
  Gets the attachment with Gmail `partId` `part_id` of a message.

  Requests the message in `format=full` and selects the part with
  `Jido.Connect.Gmail.MIME.Traversal.attachment/3`. Gmail's
  `attachments.get` is requested only for a part without inline data, for
  the `attachmentId` of the same `format=full` response. The data is checked
  as the traversal describes and returned as Gmail sent it.
  """
  def get_attachment_content(%{message_id: message_id, part_id: part_id}, access_token)
      when is_binary(message_id) and is_binary(part_id) and is_binary(access_token) do
    with {:ok, resource} <- get_message_content(%{message_id: message_id}, access_token),
         {:ok, resource_id} <- resource_id(resource, message_id, part_id),
         {:ok, entry, location} <- Traversal.attachment(Data.get(resource, "payload"), part_id),
         {:ok, data} <- attachment_data(location, resource_id, entry, access_token) do
      %{
        message_id: resource_id,
        thread_id: Data.get(resource, "threadId"),
        history_id: string(Data.get(resource, "historyId")),
        data: data
      }
      |> Map.merge(entry)
      |> AttachmentContent.new()
      |> case do
        {:ok, content} -> {:ok, content}
        {:error, _errors} -> invalid_response(%{message_id: resource_id, part_id: part_id})
      end
    end
  end

  defp attachment_data({:inline, data}, _message_id, _entry, _access_token), do: {:ok, data}

  defp attachment_data({:external, attachment_id}, message_id, entry, access_token) do
    params = %{message_id: message_id, attachment_id: attachment_id}

    with {:ok, attachment} <- Users.get_attachment(params, access_token) do
      case attachment do
        %{data: data} when is_binary(data) ->
          with :ok <- Traversal.verify_attachment_data(entry, data), do: {:ok, data}

        _no_data ->
          invalid_response(%{message_id: message_id, part_id: entry.part_id})
      end
    end
  end

  defp resource_id(resource, message_id, part_id) do
    case Data.get(resource, "id") do
      id when is_binary(id) and id != "" -> {:ok, id}
      _missing -> invalid_response(%{message_id: message_id, part_id: part_id})
    end
  end

  # Details name IDs only, never message data.
  defp invalid_response(details) do
    {:error,
     Error.provider("Gmail attachment content response was invalid",
       provider: :google,
       reason: :invalid_response,
       details: details
     )}
  end

  # Gmail sends historyId as a string. An integer becomes one; any other value
  # stays as it is, so the struct schema rejects it.
  defp string(value) when is_integer(value), do: Integer.to_string(value)
  defp string(value), do: value

  defp handle_response({:ok, %{status: status, body: body}}, _message)
       when status in 200..299 and is_map(body),
       do: {:ok, body}

  defp handle_response({:ok, %{status: status, body: body}}, message)
       when status in 200..299,
       do: Transport.invalid_success_response(message, body)

  defp handle_response(response, _message), do: Transport.handle_error_response(response)

  defp encode_path_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)
end
