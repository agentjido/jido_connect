defmodule Jido.Connect.GitHub.Connections do
  @moduledoc """
  Helpers for shaping host-owned GitHub `Jido.Connect.Connection` records.

  The helpers do not store credentials. They only build durable connection
  metadata for the host app to persist while tokens/private keys remain in the
  host-owned credential store.
  """

  alias Jido.Connect
  alias Jido.Connect.Data

  @default_oauth_scopes ["read:user"]
  @default_installation_scopes [
    "actions:read",
    "actions:write",
    "metadata:read",
    "issues:read",
    "issues:write"
  ]

  @doc """
  Builds a user-level GitHub OAuth/manual-token connection.

  `:tenant_id` is required. `:owner_id` is required unless the GitHub user
  payload includes `login` or `id`.
  """
  def user_connection(opts) when is_list(opts), do: user_connection(%{}, opts)

  def user_connection(attrs, opts) when is_map(attrs) and is_list(opts) do
    tenant_id = fetch_required!(opts, :tenant_id)
    owner_type = Keyword.get(opts, :owner_type, :app_user)
    owner_id = Keyword.get(opts, :owner_id) || github_user_login(attrs) || github_user_id(attrs)

    owner_id =
      owner_id ||
        raise ArgumentError,
              "GitHub user connection requires :owner_id or a user payload with login/id"

    connection_attrs = %{
      id: Keyword.get(opts, :id, "github-user-#{owner_id}"),
      provider: :github,
      profile: :user,
      tenant_id: tenant_id,
      owner_type: owner_type,
      owner_id: to_string(owner_id),
      subject: user_subject(attrs, Keyword.get(opts, :subject, %{})),
      status: Keyword.get(opts, :status, :connected),
      credential_ref: Keyword.get(opts, :credential_ref),
      scopes: scopes(attrs, opts, @default_oauth_scopes),
      metadata: metadata(attrs, opts, %{mode: :github_oauth})
    }

    Connect.Connection.new(connection_attrs)
  end

  @doc """
  Builds a user connection for a host-owned GitHub App user access token.

  GitHub App user tokens do not use the broad OAuth `repo` scope. The host
  supplies the verified permissions for the exact installation, repository,
  or public-read target that the action can access. The connection contains
  only permission-derived scope names and public binding metadata. It never
  contains the access token.
  """
  def github_app_user_connection(attrs, opts) when is_map(attrs) and is_list(opts) do
    permissions = Keyword.get(opts, :permissions, Data.get(attrs, "permissions", %{}))

    metadata =
      opts
      |> Keyword.get(:metadata, %{})
      |> Map.put(:token_kind, :github_app_user)

    opts =
      opts
      |> Keyword.put(:metadata, metadata)
      |> Keyword.put(:scopes, github_app_user_scopes(permissions, metadata))

    user_connection(attrs, opts)
  end

  @doc """
  Builds a GitHub App installation connection.

  Organization installations default to tenant-owned connections. User-account
  installations default to app-user-owned connections. Hosts can override
  `:owner_type` and `:owner_id` when their tenancy model differs.
  """
  def installation_connection(installation, opts) when is_list(opts) do
    installation = normalize_installation(installation)
    installation_id = installation_id!(installation)
    tenant_id = fetch_required!(opts, :tenant_id)
    account = Data.get(installation, "account", %{}) || %{}
    account_type = account_type(account, installation)
    owner_type = Keyword.get(opts, :owner_type, default_installation_owner_type(account_type))

    owner_id =
      Keyword.get(opts, :owner_id) ||
        default_installation_owner_id(owner_type, tenant_id, account, installation_id)

    connection_attrs = %{
      id: Keyword.get(opts, :id, "github-installation-#{installation_id}"),
      provider: :github,
      profile: :installation,
      tenant_id: tenant_id,
      owner_type: owner_type,
      owner_id: to_string(owner_id),
      subject:
        installation_subject(
          installation,
          account,
          account_type,
          Keyword.get(opts, :subject, %{})
        ),
      status: Keyword.get(opts, :status, :connected),
      credential_ref: Keyword.get(opts, :credential_ref, "github-app:#{installation_id}"),
      scopes: scopes(installation, opts, installation_scopes(installation)),
      metadata: metadata(installation, opts, installation_metadata(installation))
    }

    Connect.Connection.new(connection_attrs)
  end

  def org_installation_connection(installation, opts) when is_list(opts) do
    installation_connection(installation, Keyword.put_new(opts, :owner_type, :tenant))
  end

  def user_installation_connection(installation, opts) when is_list(opts) do
    installation_connection(installation, Keyword.put_new(opts, :owner_type, :app_user))
  end

  defp normalize_installation(installation_id) when is_integer(installation_id),
    do: %{id: installation_id}

  defp normalize_installation(installation_id) when is_binary(installation_id),
    do: %{id: installation_id}

  defp normalize_installation(%{} = installation), do: installation

  defp installation_id!(installation) do
    installation
    |> Data.get("id")
    |> case do
      nil -> raise ArgumentError, "GitHub installation connection requires installation id"
      id -> to_string(id)
    end
  end

  defp account_type(account, installation) do
    Data.get(account, "type") || Data.get(installation, "account_type")
  end

  defp default_installation_owner_type("Organization"), do: :tenant
  defp default_installation_owner_type("User"), do: :app_user
  defp default_installation_owner_type(_other), do: :installation

  defp default_installation_owner_id(:tenant, tenant_id, _account, _installation_id),
    do: tenant_id

  defp default_installation_owner_id(_owner_type, _tenant_id, account, installation_id) do
    Data.get(account, "login") || installation_id
  end

  defp user_subject(attrs, extra) do
    %{
      github_login: github_user_login(attrs),
      github_user_id: github_user_id(attrs)
    }
    |> Map.merge(extra || %{})
    |> Data.compact()
  end

  defp installation_subject(installation, account, account_type, extra) do
    %{
      installation_id: installation_id!(installation),
      account_login: Data.get(account, "login") || Data.get(installation, "account_login"),
      account_id: Data.get(account, "id") || Data.get(installation, "account_id"),
      account_type: account_type
    }
    |> Map.merge(extra || %{})
    |> Data.compact()
  end

  defp installation_metadata(installation) do
    %{
      mode: :github_app,
      installation_id: installation_id!(installation),
      repository_selection: Data.get(installation, "repository_selection"),
      app_id: Data.get(installation, "app_id")
    }
  end

  defp metadata(attrs, opts, defaults) do
    defaults
    |> Map.merge(Data.get(attrs, "metadata", %{}) || %{})
    |> Map.merge(Keyword.get(opts, :metadata, %{}) || %{})
    |> Data.compact()
  end

  defp scopes(attrs, opts, default) do
    attrs
    |> Data.get("scopes", Data.get(attrs, "scope", Keyword.get(opts, :scopes, default)))
    |> normalize_scopes()
  end

  defp installation_scopes(installation) do
    installation
    |> Data.get("permissions")
    |> permission_scopes()
    |> case do
      [] -> @default_installation_scopes
      scopes -> scopes
    end
  end

  defp permission_scopes(permissions) when is_map(permissions) do
    permissions
    |> Enum.flat_map(fn {permission, level} ->
      permission_scope(to_string(permission), to_string(level))
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp permission_scopes(_permissions), do: []

  defp github_app_user_scopes(permissions, metadata) do
    permissions
    |> permission_scopes()
    |> maybe_add_public_read(metadata)
  end

  defp maybe_add_public_read(scopes, metadata) do
    if Data.get(metadata, "public_read", false),
      do: Enum.uniq(["public:read" | scopes]),
      else: scopes
  end

  defp permission_scope(permission, "write"), do: ["#{permission}:read", "#{permission}:write"]
  defp permission_scope(permission, "admin"), do: ["#{permission}:read", "#{permission}:write"]
  defp permission_scope(permission, "read"), do: ["#{permission}:read"]
  defp permission_scope(_permission, _level), do: []

  defp normalize_scopes(scopes) when is_binary(scopes) do
    scopes
    |> String.split([",", " "], trim: true)
    |> Enum.uniq()
  end

  defp normalize_scopes(scopes) when is_list(scopes), do: Enum.map(scopes, &to_string/1)
  defp normalize_scopes(_scopes), do: []

  defp github_user_login(attrs), do: Data.get(attrs, "login") || Data.get(attrs, "github_login")

  defp github_user_id(attrs) do
    case Data.get(attrs, "id") || Data.get(attrs, "github_user_id") do
      nil -> nil
      id -> to_string(id)
    end
  end

  defp fetch_required!(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} when value not in [nil, ""] -> value
      _missing -> raise ArgumentError, "GitHub connection requires #{inspect(key)}"
    end
  end
end
