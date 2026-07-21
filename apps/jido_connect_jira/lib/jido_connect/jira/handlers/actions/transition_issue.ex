defmodule Jido.Connect.Jira.Handlers.Actions.TransitionIssue do
  @moduledoc false

  alias Jido.Connect.Jira.Client

  def run(input, %{credentials: credentials}) do
    opts = build_transition_opts(input)

    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, result} <-
           client.transition_issue(input.issue_key, input.transition_id, token, opts) do
      {:ok, result}
    end
  end

  defp build_transition_opts(input) do
    case Map.get(input, :fields) do
      nil -> []
      fields -> [fields: fields]
    end
  end

  defp fetch_client(%{jira_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
