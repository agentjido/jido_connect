defmodule Jido.Connect.Gmail.Client.Content do
  @moduledoc """
  Gmail message and thread content requests.

  Both requests ask for Gmail's `format=full` representation, which carries
  every MIME part with its headers and the body data that Gmail keeps inline.
  They return the decoded Gmail resource unchanged. The content actions walk it
  with `Jido.Connect.Gmail.MIME.Traversal`, fetch text parts stored behind an
  `attachmentId` with `get_attachment/2` and build the content structs.
  """

  alias Jido.Connect.Gmail.Client.Transport
  alias Jido.Connect.Http

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

  defp handle_response({:ok, %{status: status, body: body}}, _message)
       when status in 200..299 and is_map(body),
       do: {:ok, body}

  defp handle_response({:ok, %{status: status, body: body}}, message)
       when status in 200..299,
       do: Transport.invalid_success_response(message, body)

  defp handle_response(response, _message), do: Transport.handle_error_response(response)

  defp encode_path_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)
end
