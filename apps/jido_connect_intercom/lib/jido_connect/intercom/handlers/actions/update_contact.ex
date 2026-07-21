defmodule Jido.Connect.Intercom.Handlers.Actions.UpdateContact do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Intercom.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, contact_id} <- validate_contact_id(Map.get(input, :contact_id)),
         {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, contact} <- client.update_contact(contact_id, input, token, []) do
      {:ok, contact}
    end
  end

  defp validate_contact_id(contact_id) when is_binary(contact_id) and byte_size(contact_id) > 0 do
    {:ok, contact_id}
  end

  defp validate_contact_id(_contact_id) do
    {:error,
     Error.validation("Intercom contact_id is required",
       reason: :invalid_contact_id,
       subject: :contact_id
     )}
  end

  defp fetch_client(%{intercom_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
