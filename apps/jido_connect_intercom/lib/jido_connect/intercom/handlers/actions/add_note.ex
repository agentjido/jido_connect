defmodule Jido.Connect.Intercom.Handlers.Actions.AddNote do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Intercom.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, conversation_id} <-
           validate_conversation_id(Map.get(input, :conversation_id)),
         {:ok, body} <- validate_body(Map.get(input, :body)),
         {:ok, admin_id} <- validate_admin_id(Map.get(input, :admin_id)),
         {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, part} <-
           client.add_note(conversation_id, %{body: body, admin_id: admin_id}, token, []) do
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
     Error.validation("Note body is required",
       reason: :invalid_body,
       subject: :body
     )}
  end

  defp validate_admin_id(admin_id) when is_binary(admin_id) and byte_size(admin_id) > 0 do
    {:ok, admin_id}
  end

  defp validate_admin_id(_admin_id) do
    {:error,
     Error.validation("Admin ID is required for notes",
       reason: :invalid_admin_id,
       subject: :admin_id
     )}
  end

  defp fetch_client(%{intercom_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
