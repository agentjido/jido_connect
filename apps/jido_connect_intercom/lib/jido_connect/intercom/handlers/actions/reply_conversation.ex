defmodule Jido.Connect.Intercom.Handlers.Actions.ReplyConversation do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Intercom.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, conversation_id} <-
           validate_conversation_id(Map.get(input, :conversation_id)),
         {:ok, _body} <- validate_body(Map.get(input, :body)),
         {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, part} <-
           client.reply_conversation(conversation_id, input, token, []) do
      {:ok, part}
    end
  end

  defp validate_conversation_id(id) when is_binary(id) and byte_size(id) > 0, do: {:ok, id}

  defp validate_conversation_id(_id) do
    {:error,
     Error.validation("Intercom conversation_id is required",
       reason: :invalid_conversation_id,
       subject: :conversation_id
     )}
  end

  defp validate_body(body) when is_binary(body) and byte_size(body) > 0, do: {:ok, body}

  defp validate_body(_body) do
    {:error,
     Error.validation("Reply body is required",
       reason: :invalid_body,
       subject: :body
     )}
  end

  defp fetch_client(%{intercom_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
