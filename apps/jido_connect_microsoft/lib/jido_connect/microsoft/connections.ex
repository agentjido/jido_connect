defmodule Jido.Connect.Microsoft.Connections do
  @moduledoc """
  Helpers for shaping host-owned Microsoft `Jido.Connect.Connection` records.

  These helpers do not store credentials. They only produce durable connection
  metadata that host applications can persist while credentials remain in
  host-owned storage.
  """

  alias Jido.Connect.{Connection, Data}
  alias Jido.Connect.Microsoft.{Account, AuthProfiles, Scopes}

  @doc "Builds a user-level Microsoft OAuth connection."
  @spec user_connection(map() | keyword(), keyword()) ::
          {:ok, Connection.t()} | {:error, term()}
  def user_connection(opts) when is_list(opts), do: user_connection(%{}, opts)

  def user_connection(attrs, opts) when is_map(attrs) and is_list(opts) do
    tenant_id = fetch_required!(opts, :tenant_id)
    account = Account.from_graph_user!(attrs)
    owner_type = Keyword.get(opts, :owner_type, :app_user)

    owner_id =
      Keyword.get(opts, :owner_id) ||
        account.email ||
        account.id ||
        raise ArgumentError,
              "Microsoft user connection requires :owner_id or a graph user payload with email/id"

    %{
      id: Keyword.get(opts, :id, "microsoft-user-#{owner_id}"),
      provider: :microsoft,
      profile: :user,
      tenant_id: tenant_id,
      owner_type: owner_type,
      owner_id: to_string(owner_id),
      subject: account |> Account.to_subject() |> Map.merge(Keyword.get(opts, :subject, %{})),
      status: Keyword.get(opts, :status, :connected),
      credential_ref: Keyword.get(opts, :credential_ref),
      scopes: scopes(attrs, opts, AuthProfiles.fetch!(:user).default_scopes),
      metadata: metadata(attrs, opts, %{mode: :microsoft_oauth})
    }
    |> Connection.new()
  end

  @doc "Builds a tenant-owned Microsoft application connection."
  @spec application_connection(map() | keyword(), keyword()) ::
          {:ok, Connection.t()} | {:error, term()}
  def application_connection(opts) when is_list(opts), do: application_connection(%{}, opts)

  def application_connection(attrs, opts) when is_map(attrs) and is_list(opts) do
    tenant_id = fetch_required!(opts, :tenant_id)

    application_id =
      Data.get(
        attrs,
        "application_id",
        Data.get(attrs, "client_id", Keyword.get(opts, :application_id))
      ) ||
        raise ArgumentError, "Microsoft application connection requires :application_id"

    owner_id = Keyword.get(opts, :owner_id, tenant_id)

    %{
      id:
        Keyword.get(
          opts,
          :id,
          "microsoft-application-#{tenant_id}-#{application_id}"
        ),
      provider: :microsoft,
      profile: :application,
      tenant_id: tenant_id,
      owner_type: Keyword.get(opts, :owner_type, :tenant),
      owner_id: to_string(owner_id),
      subject:
        %{microsoft_application_id: to_string(application_id)}
        |> Map.merge(Keyword.get(opts, :subject, %{})),
      status: Keyword.get(opts, :status, :connected),
      credential_ref: Keyword.get(opts, :credential_ref),
      scopes: scopes(attrs, opts, AuthProfiles.fetch!(:application).default_scopes),
      metadata: metadata(attrs, opts, %{mode: :microsoft_client_credentials})
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
      _missing -> raise ArgumentError, "Microsoft connection requires #{inspect(key)}"
    end
  end
end
