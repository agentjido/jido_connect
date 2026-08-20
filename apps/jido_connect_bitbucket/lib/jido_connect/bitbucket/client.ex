defmodule Jido.Connect.Bitbucket.Client do
  @moduledoc "Bitbucket Cloud REST client boundary."

  alias Jido.Connect.Bitbucket.Client.Request

  @doc "Builds a request from the provider handler runtime."
  defdelegate request_context(runtime), to: Request, as: :from_runtime

  @doc "Returns the injected provider client or the built-in client."
  def resolve(%{provider_client: client}) when is_atom(client) and not is_nil(client), do: client
  def resolve(_runtime), do: __MODULE__

  @doc "Lists pull requests in one Bitbucket repository."
  defdelegate list_pull_requests(workspace, repository, request, opts \\ []),
    to: Jido.Connect.Bitbucket.Client.PullRequests,
    as: :list
end
