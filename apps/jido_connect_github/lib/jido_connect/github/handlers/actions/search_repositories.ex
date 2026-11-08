defmodule Jido.Connect.GitHub.Handlers.Actions.SearchRepositories do
  @moduledoc false

  alias Jido.Connect.{Data, Error}

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- fetch_client(credentials),
         {:ok, result} <-
           client.search_repositories(search_params(input), Map.get(credentials, :access_token)) do
      {:ok,
       %{
         repositories: Enum.map(Map.fetch!(result, :repositories), &normalize_repository/1),
         total_count: Map.get(result, :total_count)
       }}
    end
  end

  defp fetch_client(%{github_client: client}) when is_atom(client), do: {:ok, client}

  defp fetch_client(_credentials) do
    {:error, Error.config("GitHub client module is required", key: :github_client)}
  end

  defp search_params(input) do
    %{
      q: search_query(input),
      sort: Map.get(input, :sort, "updated"),
      direction: Map.get(input, :direction, "desc"),
      page: Map.get(input, :page, 1),
      per_page: Map.get(input, :per_page, 30)
    }
  end

  defp search_query(input) do
    [
      Map.fetch!(input, :query),
      qualifier("user", Map.get(input, :user)),
      qualifier("org", Map.get(input, :org)),
      qualifier("language", Map.get(input, :language)),
      qualifier("topic", Map.get(input, :topic)),
      visibility_qualifier(Map.get(input, :visibility, "all")),
      boolean_qualifier("archived", Map.get(input, :archived)),
      boolean_qualifier("fork", Map.get(input, :fork))
    ]
    |> Enum.reject(&blank?/1)
    |> Enum.join(" ")
  end

  defp visibility_qualifier("all"), do: nil
  defp visibility_qualifier(value), do: qualifier("is", value)

  defp boolean_qualifier(_name, nil), do: nil
  defp boolean_qualifier(name, value) when is_boolean(value), do: "#{name}:#{value}"

  defp qualifier(_name, value) when value in [nil, ""], do: nil
  defp qualifier(name, value), do: "#{name}:#{value}"

  defp blank?(value), do: is_nil(value) or value == ""

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
      url: Map.get(repository, :url),
      description: Map.get(repository, :description),
      language: Map.get(repository, :language),
      stargazers_count: Map.get(repository, :stargazers_count),
      forks_count: Map.get(repository, :forks_count),
      open_issues_count: Map.get(repository, :open_issues_count),
      archived: Map.get(repository, :archived),
      fork: Map.get(repository, :fork),
      updated_at: Map.get(repository, :updated_at),
      pushed_at: Map.get(repository, :pushed_at)
    }
    |> Data.compact()
  end
end
