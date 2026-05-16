defmodule Jido.Connect.Linear.Handlers.Actions.GetIssue do
  @moduledoc false

  alias Jido.Connect.Linear.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, issue} <-
           client.get_issue(input.issue_id, token) do
      {:ok, issue}
    end
  end

  defp fetch_client(%{linear_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
