defmodule Jido.Connect.CredentialLease do
  @moduledoc """
  Short-lived non-durable view of credential material.

  A lease is a runtime capability minted by a host app from durable connection
  storage. It may carry connection binding metadata so provider packages and
  adjacent Jido packages can consume the same short-lived credential envelope
  without learning how the host stores OAuth tokens, app installation keys, API
  keys, or other credential material.
  """

  alias Jido.Connect.{Connection, Data, Error}

  @schema Zoi.struct(
            __MODULE__,
            %{
              connection_id: Zoi.string(),
              provider: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              profile: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              tenant_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              owner_type:
                Zoi.enum([:user, :tenant, :org, :system, :installation, :app_user])
                |> Zoi.nullish()
                |> Zoi.optional(),
              owner_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              subject: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              scopes: Zoi.list(Zoi.string()) |> Zoi.nullish() |> Zoi.optional(),
              issued_at: Zoi.datetime() |> Zoi.nullish() |> Zoi.optional(),
              expires_at: Zoi.datetime(),
              fields: Zoi.map(),
              metadata: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new!(attrs), do: Zoi.parse!(@schema, attrs)
  def new(attrs), do: Zoi.parse(@schema, attrs)

  @doc "Fetches a credential field by atom or string key."
  @spec fetch_field(t(), atom() | String.t()) :: {:ok, term()} | :error
  def fetch_field(%__MODULE__{} = lease, key) when is_atom(key) or is_binary(key) do
    case Data.get(lease.fields, key, :__jido_connect_missing__) do
      :__jido_connect_missing__ -> :error
      value -> {:ok, value}
    end
  end

  @doc "Gets a credential field by atom or string key."
  @spec get_field(t(), atom() | String.t(), term()) :: term()
  def get_field(%__MODULE__{} = lease, key, default \\ nil)
      when is_atom(key) or is_binary(key) do
    Data.get(lease.fields, key, default)
  end

  @doc "Returns non-secret credential field keys."
  @spec field_keys(t()) :: [term()]
  def field_keys(%__MODULE__{} = lease) when is_map(lease.fields) do
    Map.keys(lease.fields)
  end

  @doc """
  Returns a JSON-safe, non-secret description of the lease.

  Raw credential fields are intentionally represented only by key names.
  Hosts that use prepare/commit must advance a non-secret revision in `metadata`
  each time credential values change. The prepared-action lease hash uses this
  public map, so changed `fields` values alone do not invalidate an approval.
  """
  @spec to_public_map(t()) :: map()
  def to_public_map(%__MODULE__{} = lease) do
    %{
      connection_id: lease.connection_id,
      provider: lease.provider,
      profile: lease.profile,
      tenant_id: lease.tenant_id,
      owner_type: lease.owner_type,
      owner_id: lease.owner_id,
      subject: lease.subject,
      scopes: lease.scopes,
      issued_at: iso8601(lease.issued_at),
      expires_at: iso8601(lease.expires_at),
      field_keys: field_keys(lease),
      metadata: Jido.Connect.Sanitizer.sanitize(lease.metadata, :transport)
    }
  end

  @doc "Returns the remaining lease TTL in seconds."
  @spec ttl_seconds(t(), DateTime.t()) :: integer()
  def ttl_seconds(%__MODULE__{} = lease, now \\ DateTime.utc_now()) do
    DateTime.diff(lease.expires_at, now, :second)
    |> max(0)
  end

  @doc """
  Builds a credential lease bound to a durable host-owned connection.

  `fields` is the only place raw credential material belongs. The copied
  provider/profile/owner/scope metadata is intentionally non-secret and lets
  runtime packages validate that the lease is being used with the connection it
  was minted for.
  """
  @spec from_connection(Connection.t(), map(), keyword()) ::
          {:ok, t()} | {:error, term()}
  def from_connection(%Connection{} = connection, fields, opts \\ []) when is_map(fields) do
    connection
    |> connection_lease_attrs(fields, opts)
    |> new()
  end

  @doc "Bang variant of `from_connection/3`."
  @spec from_connection!(Connection.t(), map(), keyword()) :: t()
  def from_connection!(%Connection{} = connection, fields, opts \\ []) when is_map(fields) do
    connection
    |> connection_lease_attrs(fields, opts)
    |> new!()
  end

  @doc "Returns true when the lease has expired at `now`."
  @spec expired?(t(), DateTime.t()) :: boolean()
  def expired?(%__MODULE__{} = lease, now \\ DateTime.utc_now()) do
    DateTime.compare(lease.expires_at, now) != :gt
  end

  @doc "Returns `:ok` for active leases or a stable auth error for expired leases."
  @spec require_unexpired(t(), DateTime.t()) :: :ok | {:error, Error.AuthError.t()}
  def require_unexpired(%__MODULE__{} = lease, now \\ DateTime.utc_now()) do
    if expired?(lease, now) do
      {:error, Error.credential_lease_expired(lease.expires_at)}
    else
      :ok
    end
  end

  @doc """
  Returns the scopes that should be used for authorization checks.

  A nil lease scope means "scope not encoded in this legacy/foreign lease", so
  authorization falls back to the durable connection scopes. When a lease does
  carry scopes, authorization uses the intersection of the durable connection
  scopes and the lease scopes. An explicit empty list means the lease carries no
  scopes and should fail scoped operations.
  """
  @spec effective_scopes(t(), Connection.t()) :: [String.t()]
  def effective_scopes(%__MODULE__{scopes: nil}, %Connection{scopes: scopes}), do: scopes

  def effective_scopes(%__MODULE__{scopes: scopes}, %Connection{scopes: connection_scopes})
      when is_list(scopes) do
    connection_scopes
    |> Enum.filter(&(&1 in scopes))
  end

  @doc "Validates optional lease binding metadata against a durable connection."
  @spec validate_connection_binding(t(), Connection.t()) :: :ok | {:error, Error.AuthError.t()}
  def validate_connection_binding(%__MODULE__{} = lease, %Connection{} = connection) do
    [
      {:provider, connection.provider, lease.provider},
      {:profile, connection.profile, lease.profile},
      {:tenant_id, connection.tenant_id, lease.tenant_id},
      {:owner_type, connection.owner_type, lease.owner_type},
      {:owner_id, connection.owner_id, lease.owner_id}
    ]
    |> Enum.find(fn {_field, expected, actual} -> present?(actual) and actual != expected end)
    |> case do
      nil ->
        :ok

      {field, expected, actual} ->
        {:error,
         Error.credential_connection_mismatch(connection.id, lease.connection_id, %{
           field: field,
           expected: expected,
           actual: actual
         })}
    end
  end

  @doc "Returns true when the lease can be safely used with `connection`."
  @spec matches_connection?(t(), Connection.t()) :: boolean()
  def matches_connection?(%__MODULE__{} = lease, %Connection{} = connection) do
    lease.connection_id == connection.id and validate_connection_binding(lease, connection) == :ok
  end

  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?(_value), do: true

  defp connection_lease_attrs(%Connection{} = connection, fields, opts) do
    expires_at = Keyword.fetch!(opts, :expires_at)

    %{
      connection_id: Keyword.get(opts, :connection_id, connection.id),
      provider: connection.provider,
      profile: connection.profile,
      tenant_id: connection.tenant_id,
      owner_type: connection.owner_type,
      owner_id: connection.owner_id,
      subject: connection.subject,
      scopes: Keyword.get(opts, :scopes, connection.scopes),
      issued_at: Keyword.get(opts, :issued_at),
      expires_at: expires_at,
      fields: fields,
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  defp iso8601(nil), do: nil
  defp iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
end

defimpl Inspect, for: Jido.Connect.CredentialLease do
  import Inspect.Algebra

  def inspect(lease, opts) do
    doc =
      to_doc(
        %{
          connection_id: lease.connection_id,
          provider: lease.provider,
          profile: lease.profile,
          tenant_id: lease.tenant_id,
          owner_type: lease.owner_type,
          owner_id: lease.owner_id,
          scopes: lease.scopes,
          expires_at: lease.expires_at,
          field_keys: map_keys(lease.fields),
          metadata_keys: map_keys(lease.metadata)
        },
        opts
      )

    concat(["#Jido.Connect.CredentialLease<", doc, ">"])
  end

  defp map_keys(map) when is_map(map), do: Map.keys(map)
  defp map_keys(_value), do: []
end
