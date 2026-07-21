defmodule Jido.Connect.Linear.Handlers.Actions.ListTeams do
  @moduledoc false

  alias Jido.Connect.Linear.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, result} <-
           client.list_teams(token,
             first: Map.get(input, :first, 50),
             after: Map.get(input, :after)
           ) do
      {:ok, result}
    end
  end

  defp fetch_client(%{linear_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
