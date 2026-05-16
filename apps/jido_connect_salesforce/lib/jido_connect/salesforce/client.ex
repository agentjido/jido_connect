defmodule Jido.Connect.Salesforce.Client do
  @moduledoc "Salesforce REST API client boundary."

  alias Jido.Connect.Salesforce.Client.{Contacts, Leads, Objects, Tasks, Transport}

  defdelegate get_contact(params, credentials), to: Contacts
  defdelegate list_contacts(params, credentials), to: Contacts
  defdelegate create_contact(params, credentials), to: Contacts
  defdelegate update_contact(params, credentials), to: Contacts

  defdelegate create_lead(params, credentials), to: Leads
  defdelegate update_lead(params, credentials), to: Leads

  defdelegate create_task(params, credentials), to: Tasks
  defdelegate update_task(params, credentials), to: Tasks

  defdelegate query(params, credentials), to: Objects
  defdelegate get_record(params, credentials), to: Objects
  defdelegate create_record(params, credentials), to: Objects
  defdelegate update_record(params, credentials), to: Objects
  defdelegate describe_object(params, credentials), to: Objects
  defdelegate list_recent(params, credentials), to: Objects
  defdelegate query_more(params, credentials), to: Objects

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
