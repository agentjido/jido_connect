defmodule Jido.Connect.Salesforce.Client do
  @moduledoc "Salesforce REST API client boundary."

  alias Jido.Connect.Salesforce.Client.{Contacts, Transport}

  defdelegate get_contact(params, credentials), to: Contacts
  defdelegate list_contacts(params, credentials), to: Contacts
  defdelegate create_contact(params, credentials), to: Contacts

  @doc """
  Returns the configured or injected client module.

  When a `:salesforce_client` key is present in credentials (e.g., from a test
  lease), that module is used. Otherwise falls back to
  `Jido.Connect.Salesforce.Client`.
  """
  def resolve(%{salesforce_client: client}) when is_atom(client), do: client
  def resolve(_credentials), do: __MODULE__

  @doc "Extracts the bearer token from credential fields."
  def credential_token(credentials) do
    Map.get(credentials, :access_token)
  end

  @doc "Extracts the Salesforce instance URL from credential fields."
  def instance_url(credentials) do
    Map.get(credentials, :instance_url) || Transport.default_instance_url()
  end
end
