defmodule Jido.Connect.HubSpot.Client do
  @moduledoc "HubSpot API client boundary."

  alias Jido.Connect.HubSpot.Client.{Companies, Contacts, Deals}

  defdelegate get_contact(params, access_token), to: Contacts
  defdelegate list_contacts(params, access_token), to: Contacts
  defdelegate search_contacts(params, access_token), to: Contacts
  defdelegate get_company(params, access_token), to: Companies
  defdelegate list_companies(params, access_token), to: Companies
  defdelegate search_companies(params, access_token), to: Companies
  defdelegate get_deal(params, access_token), to: Deals
  defdelegate list_deals(params, access_token), to: Deals
  defdelegate search_deals(params, access_token), to: Deals

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
