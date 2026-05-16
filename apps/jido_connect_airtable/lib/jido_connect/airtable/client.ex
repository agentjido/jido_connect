defmodule Jido.Connect.Airtable.Client do
  @moduledoc "Airtable API client boundary."

  alias Jido.Connect.Airtable.Client.{Bases, Records}

  defdelegate list_bases(params, access_token), to: Bases
  defdelegate get_base(params, access_token), to: Bases
  defdelegate list_tables(params, access_token), to: Bases
  defdelegate list_records(params, access_token), to: Records
  defdelegate get_record(params, access_token), to: Records
  defdelegate create_record(params, access_token), to: Records
  defdelegate update_record(params, access_token), to: Records
  defdelegate delete_record(params, access_token), to: Records

  @doc """
  Returns the configured or injected client module.

  When a `:airtable_client` key is present in credentials (e.g., from a test
  lease), that module is used. Otherwise falls back to
  `Jido.Connect.Airtable.Client`.
  """
  def resolve(%{airtable_client: client}) when is_atom(client), do: client
  def resolve(_credentials), do: __MODULE__

  @doc "Extracts the bearer token from credential fields."
  def credential_token(credentials) do
    Map.get(credentials, :api_key) || Map.get(credentials, :access_token)
  end
end
