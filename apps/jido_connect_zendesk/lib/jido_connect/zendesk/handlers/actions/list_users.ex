defmodule Jido.Connect.Zendesk.Handlers.Actions.ListUsers do
  @moduledoc false

  alias Jido.Connect.Zendesk.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, result} <-
           client.list_users(token,
             page: Map.get(input, :page),
             per_page: Map.get(input, :per_page),
             role: Map.get(input, :role)
           ) do
      {:ok, result}
    end
  end

  defp fetch_client(%{zendesk_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
