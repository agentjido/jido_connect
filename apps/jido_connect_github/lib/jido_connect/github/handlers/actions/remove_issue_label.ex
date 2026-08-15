defmodule Jido.Connect.GitHub.Handlers.Actions.RemoveIssueLabel do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, label} <- validate_label(Map.fetch!(input, :label)),
         {:ok, client} <- fetch_client(credentials),
         {:ok, labels} <-
           client.remove_issue_label(
             Map.fetch!(input, :repo),
             Map.fetch!(input, :issue_number),
             label,
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{labels: labels}}
    end
  end

  defp validate_label(label) when is_binary(label) and label != "", do: {:ok, label}

  defp validate_label(_label) do
    {:error,
     Error.validation("A GitHub issue label name is required",
       reason: :empty_label,
       subject: :label
     )}
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end
end
