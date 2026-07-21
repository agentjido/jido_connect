defmodule Jido.Connect.MicrosoftOutlook.Handlers.Actions.ReplyAllMessage do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport

  @doc """
  Reply-all to an existing message.

  POST /me/messages/{message_id}/replyAll with a JSON body containing the comment.
  Returns 202 Accepted with no body on success.
  """
  def run(input, %{credentials: %{access_token: access_token}})
      when is_binary(access_token) do
    case Map.get(input, :message_id) do
      nil ->
        {:error, :message_id_required}

      message_id ->
        body = build_reply_body(input)
        request = Transport.request(access_token)

        case Transport.request(request, :post,
               url: "/me/messages/#{message_id}/replyAll",
               json: body
             ) do
          {:ok, %{status: 202}} ->
            {:ok, %{sent: true, message_id: message_id}}

          {:ok, %{status: status}} when status in 200..299 ->
            {:ok, %{sent: true, message_id: message_id}}

          {:ok, response} ->
            Transport.handle_error_response({:ok, response},
              message: "Failed to reply-all to Outlook message"
            )

          {:error, _reason} = error ->
            Transport.handle_error_response(error,
              message: "Failed to reply-all to Outlook message"
            )
        end
    end
  end

  def run(_input, _context), do: {:error, :missing_access_token}

  defp build_reply_body(input) do
    %{"comment" => Map.get(input, :comment, "")}
  end
end
