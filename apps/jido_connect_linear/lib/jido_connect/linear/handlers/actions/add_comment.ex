defmodule Jido.Connect.Linear.Handlers.Actions.AddComment do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Linear.Client

  @doc "Adds a comment to a Linear issue. Returns `{:ok, comment}` with confirmation metadata."
  def run(input, %{credentials: credentials}) do
    with {:ok, _} <- validate_comment_input(input),
         {:ok, client} <- fetch_client(credentials),
         token <- Client.credential_token(credentials),
         {:ok, comment} <- client.add_comment(input.issue_id, input.body, token) do
      {:ok, add_confirmation(comment, :commented, input)}
    end
  end

  defp validate_comment_input(input) do
    issue_id = Map.get(input, :issue_id)
    body = Map.get(input, :body)

    cond do
      not is_binary(issue_id) or byte_size(issue_id) == 0 ->
        {:error,
         Error.validation("Linear issue_id is required",
           reason: :invalid_issue_id,
           subject: :issue_id
         )}

      not is_binary(body) or byte_size(body) == 0 ->
        {:error,
         Error.validation("Comment body is required",
           reason: :invalid_comment_body,
           subject: :body
         )}

      true ->
        {:ok, :valid}
    end
  end

  defp add_confirmation(result, action, input) do
    meta = %{
      action: action,
      issue_id: Map.get(input, :issue_id)
    }

    Map.put(result, :_confirmation, meta)
  end

  defp fetch_client(%{linear_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
