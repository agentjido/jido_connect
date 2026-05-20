defmodule Jido.Connect.Asana.Client do
  @moduledoc """
  Asana REST client facade.

  Delegates to capability-oriented client modules for workspaces, projects,
  tasks, stories, and users.

  ## Error normalization

  All methods return `{:ok, result}` or `{:error, %Jido.Connect.Error.ProviderError{}}`.
  Provider errors include normalized reason atoms:

  - `:unauthorized` (401) – missing or invalid token
  - `:forbidden` (403) – insufficient scopes
  - `:not_found` (404) – resource not found
  - `:rate_limited` (429) – Asana rate limit exceeded
  - `:server_error` (5xx) – transient Asana failures
  - `:http_error` – other HTTP errors
  - `:invalid_response` – unexpected success payload shape
  """

  defdelegate list_workspaces(access_token, opts \\ []),
    to: __MODULE__.Workspaces,
    as: :list

  defdelegate list_projects(access_token, opts \\ []),
    to: __MODULE__.Projects,
    as: :list

  defdelegate list_tasks(access_token, opts \\ []),
    to: __MODULE__.Tasks,
    as: :list

  defdelegate get_task(task_gid, access_token, opts \\ []),
    to: __MODULE__.Tasks,
    as: :get

  defdelegate search_tasks(workspace_gid, access_token, opts \\ []),
    to: __MODULE__.Tasks,
    as: :search

  defdelegate list_stories(task_gid, access_token, opts \\ []),
    to: __MODULE__.Stories,
    as: :list

  defdelegate get_user(user_gid, access_token, opts \\ []),
    to: __MODULE__.Users,
    as: :get

  defdelegate list_users(access_token, opts \\ []),
    to: __MODULE__.Users,
    as: :list

  # ---------------------------------------------------------------------------
  # Client resolution
  # ---------------------------------------------------------------------------

  @doc "Returns the configured or injected client module."
  def resolve(%{asana_client: client}) when is_atom(client), do: client
  def resolve(_credentials), do: __MODULE__

  @doc "Extracts the bearer token from credential fields."
  def credential_token(credentials) do
    Map.get(credentials, :api_key) || Map.get(credentials, :access_token)
  end
end
