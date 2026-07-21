defmodule Jido.Connect.Jira.Handlers.Actions.AddComment do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Jira.Client

  def run(input, %{credentials: credentials}) do
    with {:ok, body} <- validate_body(Map.get(input, :body)),
         {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, comment} <- client.add_comment(input.issue_key, body, token) do
      {:ok, comment}
    end
  end

  defp validate_body(body) when is_binary(body) and byte_size(body) > 0 do
    {:ok, body}
  end

  defp validate_body(_body) do
    {:error,
     Error.validation("Jira comment body is required",
       reason: :invalid_comment_body,
       subject: :body
     )}
  end

  defp fetch_client(%{jira_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
