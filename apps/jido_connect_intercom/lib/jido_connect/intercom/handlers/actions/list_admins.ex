defmodule Jido.Connect.Intercom.Handlers.Actions.ListAdmins do
  @moduledoc false

  alias Jido.Connect.Intercom.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, result} <-
           client.list_admins(token,
             per_page: Map.get(input, :per_page)
           ) do
      {:ok, result}
    end
  end

  defp fetch_client(%{intercom_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
