defmodule Jido.Connect.Zendesk.Client do
  @moduledoc """
  Zendesk REST client boundary.

  New code should prefer the API-area modules under
  `Jido.Connect.Zendesk.Client.*` for a narrower dependency surface.

  API methods will be added when action handlers are implemented in
  subsequent waves.
  """

  @doc "Returns the configured or injected client module."
  def resolve(%{zendesk_client: client}) when is_atom(client), do: client
  def resolve(_credentials), do: __MODULE__

  @doc "Extracts the bearer token from credential fields."
  def credential_token(credentials) do
    Map.get(credentials, :api_key) || Map.get(credentials, :access_token)
  end
end
