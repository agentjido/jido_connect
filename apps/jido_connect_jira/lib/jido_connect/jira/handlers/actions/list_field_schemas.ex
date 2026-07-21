defmodule Jido.Connect.Jira.Handlers.Actions.ListFieldSchemas do
  @moduledoc false

  alias Jido.Connect.Jira.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, result} <-
           client.list_field_schemas(token,
             expand: Map.get(input, :expand)
           ) do
      {:ok, result}
    end
  end

  defp fetch_client(%{jira_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
