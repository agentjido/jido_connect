defmodule Jido.Connect.Tempo.Client do
  @moduledoc """
  Tempo REST v4 client boundary of the Tempo actions.

  Each call receives a `Jido.Connect.Tempo.Client.Request`, which binds the
  selected connection, its account ID, its origin and the leased token.
  Handlers call the client returned by `resolve/1`, so a host or a test can
  inject its own module as `provider_client`.
  """

  alias Jido.Connect.Tempo.Client.{Request, Worklogs}

  @doc "Builds a request from the provider handler runtime."
  defdelegate request_context(runtime), to: Request, as: :from_runtime

  @doc "Returns the injected provider client or the built-in client."
  @spec resolve(map()) :: module()
  def resolve(%{provider_client: client}) when is_atom(client) and not is_nil(client), do: client
  def resolve(_runtime), do: __MODULE__

  @doc """
  Reads every worklog of the request's account with a booking day from
  `:from` to `:to`, both inclusive. See
  `Jido.Connect.Tempo.Client.Worklogs.list_own/2`.
  """
  defdelegate list_own_worklogs(request, opts), to: Worklogs, as: :list_own
end
