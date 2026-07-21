defmodule Jido.Connect.Linear.Handlers.Actions.SearchIssues do
  @moduledoc false

  alias Jido.Connect.Linear.Client

  def run(input, %{credentials: credentials}) do
    filter = Map.get(input, :filter, %{})

    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, result} <-
           client.search_issues(filter, token,
             first: Map.get(input, :first, 50),
             after: Map.get(input, :after),
             order_by: Map.get(input, :order_by, "updatedAt")
           ) do
      {:ok, result}
    end
  end

  defp fetch_client(%{linear_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
