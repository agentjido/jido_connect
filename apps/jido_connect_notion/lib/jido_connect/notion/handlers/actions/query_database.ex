defmodule Jido.Connect.Notion.Handlers.Actions.QueryDatabase do
  @moduledoc false

  alias Jido.Connect.Notion.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.query_database(
             Map.fetch!(input, :database_id),
             input,
             Map.get(credentials, :api_key)
           ) do
      {:ok, result}
    end
  end

  defp fetch_client(%{notion_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
