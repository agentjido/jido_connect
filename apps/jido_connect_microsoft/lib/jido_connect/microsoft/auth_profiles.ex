defmodule Jido.Connect.Microsoft.AuthProfiles do
  @moduledoc "Shared Microsoft auth profile metadata."

  alias Jido.Connect.Microsoft.{AuthProfile, Scopes}

  @doc "Returns all shared Microsoft auth profile ids."
  @spec ids() :: [:user | :application]
  def ids, do: [:user, :application]

  @doc "Returns all shared Microsoft auth profiles."
  @spec all() :: [AuthProfile.t()]
  def all, do: Enum.map(ids(), &fetch!/1)

  @doc "Fetches a shared Microsoft auth profile."
  @spec fetch(atom()) :: {:ok, AuthProfile.t()} | :error
  def fetch(profile) when profile in [:user, :application],
    do: {:ok, fetch!(profile)}

  def fetch(_profile), do: :error

  @doc "Fetches a shared Microsoft auth profile or raises."
  @spec fetch!(atom()) :: AuthProfile.t()
  def fetch!(:user) do
    AuthProfile.new!(%{
      id: :user,
      kind: :oauth2,
      owner: :app_user,
      subject: :user,
      label: "Microsoft Graph OAuth user",
      setup: :oauth2_authorization_code,
      refresh_token_field: :refresh_token,
      credential_fields: [:access_token, :refresh_token],
      lease_fields: [:access_token],
      scopes: Scopes.user_default(),
      default_scopes: Scopes.user_default(),
      optional_scopes: Scopes.user_optional(),
      default?: true,
      metadata: %{credential_mode: :oauth2_user}
    })
  end

  def fetch!(:application) do
    AuthProfile.new!(%{
      id: :application,
      kind: :oauth2,
      owner: :tenant,
      subject: :service_principal,
      label: "Microsoft Graph application",
      setup: :oauth2_client_credentials,
      credential_fields: [:client_id, :client_secret, :tenant_id],
      lease_fields: [:access_token],
      scopes: Scopes.product(:sharepoint),
      default_scopes: [],
      optional_scopes: Scopes.product(:sharepoint),
      metadata: %{credential_mode: :oauth2_client_credentials}
    })
  end

  def fetch!(profile),
    do: raise(ArgumentError, "unknown Microsoft auth profile #{inspect(profile)}")
end
