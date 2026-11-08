defmodule Jido.Connect.GitHub.Handlers.Actions.GetRepository do
  @moduledoc false

  alias Jido.Connect.Error

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, repository} <-
           client.get_repository(
             Map.fetch!(input, :owner),
             Map.fetch!(input, :name),
             Map.get(credentials, :access_token)
           ) do
      {:ok, normalize_repository(repository)}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end

  defp normalize_repository(repository) do
    %{
      id: Map.fetch!(repository, :id),
      name: Map.fetch!(repository, :name),
      full_name: Map.fetch!(repository, :full_name),
      owner: Map.get(repository, :owner),
      private: Map.get(repository, :private),
      visibility: Map.get(repository, :visibility),
      default_branch: Map.get(repository, :default_branch),
      permissions: Map.get(repository, :permissions),
      url: Map.fetch!(repository, :url),
      archived: Map.get(repository, :archived),
      fork: Map.get(repository, :fork),
      updated_at: Map.get(repository, :updated_at)
    }
  end
end
