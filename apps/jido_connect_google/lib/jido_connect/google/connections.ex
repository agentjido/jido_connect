defmodule Jido.Connect.Google.Connections do
  @moduledoc """
  Helpers for shaping host-owned Google `Jido.Connect.Connection` records.

  These helpers do not store credentials. They only produce durable connection
  metadata that host applications can persist while credentials remain in
  host-owned storage.
  """

  alias Jido.Connect.{Connection, Data}
  alias Jido.Connect.Google.{Account, AuthProfiles, Scopes}

  @doc "Builds a user-level Google OAuth connection."
  @spec user_connection(map() | keyword(), keyword()) :: {:ok, Connection.t()} | {:error, term()}
  def user_connection(opts) when is_list(opts), do: user_connection(%{}, opts)

  def user_connection(attrs, opts) when is_map(attrs) and is_list(opts) do
    tenant_id = fetch_required!(opts, :tenant_id)
    account = Account.from_userinfo!(attrs)
    owner_type = Keyword.get(opts, :owner_type, :app_user)

    owner_id =
      Keyword.get(opts, :owner_id) ||
        account.email ||
        account.id ||
        raise ArgumentError,
              "Google user connection requires :owner_id or a userinfo payload with email/sub"

    %{
      id: Keyword.get(opts, :id, "google-user-#{owner_id}"),
      provider: :google,
      profile: :user,
      tenant_id: tenant_id,
      owner_type: owner_type,
      owner_id: to_string(owner_id),
      subject: account |> Account.to_subject() |> Map.merge(Keyword.get(opts, :subject, %{})),
      status: Keyword.get(opts, :status, :connected),
      credential_ref: Keyword.get(opts, :credential_ref),
      scopes: scopes(attrs, opts, AuthProfiles.fetch!(:user).default_scopes),
      metadata: metadata(attrs, opts, %{mode: :google_oauth})
    }
    |> Connection.new()
  end

  @doc """
  Builds metadata for a service-account connection.

  Host applications still own durable credential storage. Use
  `Jido.Connect.Google.ServiceAccount.credential_lease/3` with the host-owned
  credential payload to mint a short-lived access-token lease.
  """
  @spec service_account_connection(map(), keyword()) :: {:ok, Connection.t()} | {:error, term()}
  def service_account_connection(attrs, opts) when is_map(attrs) and is_list(opts) do
    tenant_id = fetch_required!(opts, :tenant_id)
    client_email = Data.get(attrs, "client_email") || Keyword.get(opts, :client_email)
    owner_id = Keyword.get(opts, :owner_id) || client_email || "service-account"

    %{
      id: Keyword.get(opts, :id, "google-service-account-#{owner_id}"),
      provider: :google,
      profile: :service_account,
      tenant_id: tenant_id,
      owner_type: Keyword.get(opts, :owner_type, :system),
      owner_id: to_string(owner_id),
      subject:
        %{
          client_email: client_email,
          project_id: Data.get(attrs, "project_id")
        }
        |> Data.compact()
        |> Map.merge(Keyword.get(opts, :subject, %{})),
      status: Keyword.get(opts, :status, :connected),
      credential_ref: Keyword.get(opts, :credential_ref),
      scopes: scopes(attrs, opts, []),
      metadata: metadata(attrs, opts, %{mode: :google_service_account})
    }
    |> Connection.new()
  end

  @doc """
  Builds metadata for a domain-delegated service-account connection.

  Hosts still own Workspace domain-wide delegation setup and durable credential
  storage. Use `Jido.Connect.Google.ServiceAccount.credential_lease/3` to mint
  a delegated short-lived access-token lease.
  """
  @spec domain_delegated_service_account_connection(map(), keyword()) ::
          {:ok, Connection.t()} | {:error, term()}
  def domain_delegated_service_account_connection(attrs, opts)
      when is_map(attrs) and is_list(opts) do
    tenant_id = fetch_required!(opts, :tenant_id)
    subject = fetch_required!(opts, :subject)
    client_email = Data.get(attrs, "client_email") || Keyword.get(opts, :client_email)

    %{
      id: Keyword.get(opts, :id, "google-domain-delegated-#{tenant_id}-#{subject}"),
      provider: :google,
      profile: :domain_delegated_service_account,
      tenant_id: tenant_id,
      owner_type: Keyword.get(opts, :owner_type, :tenant),
      owner_id: to_string(Keyword.get(opts, :owner_id, tenant_id)),
      subject:
        %{
          client_email: client_email,
          delegated_subject: subject,
          project_id: Data.get(attrs, "project_id")
        }
        |> Data.compact()
        |> Map.merge(Keyword.get(opts, :connection_subject, %{})),
      status: Keyword.get(opts, :status, :connected),
      credential_ref: Keyword.get(opts, :credential_ref),
      scopes: scopes(attrs, opts, []),
      metadata: metadata(attrs, opts, %{mode: :google_domain_delegation})
    }
    |> Connection.new()
  end

  defp scopes(attrs, opts, default) do
    attrs
    |> Data.get("scopes", Data.get(attrs, "scope", Keyword.get(opts, :scopes, default)))
    |> Scopes.normalize()
  end

  defp metadata(attrs, opts, defaults) do
    defaults
    |> Map.merge(Data.get(attrs, "metadata", %{}) || %{})
    |> Map.merge(Keyword.get(opts, :metadata, %{}) || %{})
    |> Data.compact()
  end

  defp fetch_required!(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} when value not in [nil, ""] -> value
      _missing -> raise ArgumentError, "Google connection requires #{inspect(key)}"
    end
  end
end
