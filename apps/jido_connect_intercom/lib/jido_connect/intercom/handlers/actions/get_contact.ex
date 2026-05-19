defmodule Jido.Connect.Intercom.Handlers.Actions.GetContact do
  @moduledoc false

  alias Jido.Connect.Intercom.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, contact} <- client.get_contact(input.contact_id, token, []) do
      {:ok, contact}
    end
  end

  defp fetch_client(%{intercom_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
