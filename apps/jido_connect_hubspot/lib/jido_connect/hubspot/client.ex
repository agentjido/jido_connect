defmodule Jido.Connect.HubSpot.Client do
  @moduledoc "HubSpot API client boundary."

  @doc """
  Returns the configured or injected client module.

  When a `:hubspot_client` key is present in credentials (e.g., from a test
  lease), that module is used. Otherwise falls back to
  `Jido.Connect.HubSpot.Client`.
  """
  def resolve(%{hubspot_client: client}) when is_atom(client), do: client
  def resolve(_credentials), do: __MODULE__

  @doc "Extracts the bearer token from credential fields."
  def credential_token(credentials) do
    Map.get(credentials, :api_key) || Map.get(credentials, :access_token)
  end
end
