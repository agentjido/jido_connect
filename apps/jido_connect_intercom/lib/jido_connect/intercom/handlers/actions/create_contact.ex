defmodule Jido.Connect.Intercom.Handlers.Actions.CreateContact do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Intercom.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, _} <- validate_contact_attrs(input),
         {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, contact} <- client.create_contact(input, token, []) do
      {:ok, contact}
    end
  end

  defp validate_contact_attrs(input) do
    has_identifying_field =
      Map.has_key?(input, :email) or
        Map.has_key?(input, :phone) or
        Map.has_key?(input, :external_id) or
        Map.has_key?(input, :name)

    if has_identifying_field do
      {:ok, :valid}
    else
      {:error,
       Error.validation("At least one of email, phone, external_id, or name is required",
         reason: :invalid_contact_attrs,
         subject: :create_contact
       )}
    end
  end

  defp fetch_client(%{intercom_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
