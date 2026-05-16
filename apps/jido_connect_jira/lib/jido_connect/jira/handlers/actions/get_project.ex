defmodule Jido.Connect.Jira.Handlers.Actions.GetProject do
  @moduledoc false

  alias Jido.Connect.Jira.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, project} <- client.get_project(input.project_key, token) do
      {:ok, project}
    end
  end

  defp fetch_client(%{jira_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
