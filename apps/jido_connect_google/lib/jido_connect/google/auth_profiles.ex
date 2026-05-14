defmodule Jido.Connect.Google.AuthProfiles do
  @moduledoc "Shared Google auth profile metadata."

  alias Jido.Connect.Google.{AuthProfile, Scopes}

  @doc "Returns all shared Google auth profile ids."
  @spec ids() :: [:user | :service_account | :domain_delegated_service_account]
  def ids, do: [:user, :service_account, :domain_delegated_service_account]

  @doc "Returns all shared Google auth profiles."
  @spec all() :: [AuthProfile.t()]
  def all, do: Enum.map(ids(), &fetch!/1)

  @doc "Fetches a shared Google auth profile."
  @spec fetch(atom()) :: {:ok, AuthProfile.t()} | :error
  def fetch(profile) when profile in [:user, :service_account, :domain_delegated_service_account],
    do: {:ok, fetch!(profile)}

  def fetch(_profile), do: :error

  @doc "Fetches a shared Google auth profile or raises."
  @spec fetch!(atom()) :: AuthProfile.t()
  def fetch!(:user) do
    AuthProfile.new!(%{
      id: :user,
      kind: :oauth2,
      owner: :app_user,
      subject: :user,
      label: "Google OAuth user",
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

  def fetch!(:service_account) do
    AuthProfile.new!(%{
      id: :service_account,
      kind: :service_account,
      owner: :system,
      subject: :service_account,
      label: "Google service account",
      setup: :google_service_account_jwt,
      credential_fields: [:client_email, :private_key, :private_key_id],
      lease_fields: [:access_token],
      default_scopes: [],
      metadata: %{credential_mode: :service_account}
    })
  end

  def fetch!(:domain_delegated_service_account) do
    AuthProfile.new!(%{
      id: :domain_delegated_service_account,
      kind: :domain_delegated_service_account,
      owner: :tenant,
      subject: :workspace_user,
      label: "Google domain-delegated service account",
      setup: :google_domain_wide_delegation,
      credential_fields: [:client_email, :private_key, :private_key_id, :subject],
      lease_fields: [:access_token],
      default_scopes: [],
      metadata: %{credential_mode: :domain_delegated_service_account}
    })
  end

  def fetch!(profile), do: raise(ArgumentError, "unknown Google auth profile #{inspect(profile)}")
end
