defmodule Jido.Connect.Notion.Handlers.Actions.CreatePage do
  @moduledoc false

  alias Jido.Connect.Notion.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, page} <-
           client.create_page(input, Map.get(credentials, :api_key)) do
      {:ok, %{page: page}}
    end
  end

  defp fetch_client(%{notion_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
