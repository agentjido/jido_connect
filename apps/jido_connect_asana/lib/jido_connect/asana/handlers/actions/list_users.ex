defmodule Jido.Connect.Asana.Handlers.Actions.ListUsers do
  @moduledoc false

  alias Jido.Connect.Asana.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, result} <-
           client.list_users(token,
             workspace: Map.get(input, :workspace),
             limit: Map.get(input, :limit),
             offset: Map.get(input, :offset)
           ) do
      {:ok, result}
    end
  end

  defp fetch_client(%{asana_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
