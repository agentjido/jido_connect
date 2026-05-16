defmodule Jido.Connect.Jira.Handlers.Actions.GetIssue do
  @moduledoc false

  alias Jido.Connect.Jira.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, issue} <- client.get_issue(input.issue_key, token) do
      {:ok, issue}
    end
  end

  defp fetch_client(%{jira_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
