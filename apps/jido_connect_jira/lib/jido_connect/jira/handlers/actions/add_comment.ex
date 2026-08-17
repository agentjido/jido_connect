defmodule Jido.Connect.Jira.Handlers.Actions.AddComment do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Jira.Client

  def run(input, runtime) do
    client = Client.resolve(runtime)

    with {:ok, body} <- validate_body(Map.get(input, :body)),
         {:ok, request} <- Client.request_context(runtime),
         {:ok, comment} <- client.add_comment(input.issue_key, body, request) do
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
end
