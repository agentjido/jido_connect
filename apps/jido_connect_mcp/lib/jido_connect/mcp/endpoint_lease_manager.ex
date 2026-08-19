defmodule Jido.Connect.MCP.EndpointLeaseManager do
  @moduledoc """
  Owns the lifetime of host-authenticated MCP endpoints.

  The manager stores only endpoint ownership evidence. The endpoint definition,
  including credential material, is passed directly to `Jido.MCP` during
  registration and is never retained here.
  """

  use GenServer

  alias Jido.Connect.{Connection, CredentialLease, Data, Error}
  alias Jido.MCP.Endpoint

  @name __MODULE__
  @default_drain_timeout_ms 5_000

  @type token :: %{
          required(:connection_id) => String.t(),
          required(:endpoint_id) => String.t(),
          required(:generation) => pos_integer(),
          required(:endpoint_fingerprint) => String.t(),
          required(:connection_revision) => non_neg_integer(),
          required(:credential_version) => non_neg_integer()
        }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, @name))
  end

  @spec acquire(Connection.t(), CredentialLease.t(), Endpoint.t()) ::
          {:ok, token()} | {:error, Error.error()}
  def acquire(%Connection{} = connection, %CredentialLease{} = lease, %Endpoint{} = endpoint) do
    call({:acquire, connection, lease, endpoint}, :infinity)
  end

  @spec release(token()) :: :ok
  def release(token) when is_map(token), do: call({:release, token})

  @doc """
  Retires the current endpoint and sets the minimum durable ownership versions
  that a replacement endpoint can use.

  The fence is monotonic. A caller cannot lower either version or clear a
  revocation tombstone without advancing at least one version.
  """
  @spec fence(Connection.t() | String.t(), keyword()) :: :ok | {:error, Error.error()}
  def fence(%Connection{id: connection_id}, opts), do: fence(connection_id, opts)

  def fence(connection_id, opts) when is_binary(connection_id) and is_list(opts) do
    with {:ok, connection_revision} <- fence_version(opts, :connection_revision),
         {:ok, credential_version} <- fence_version(opts, :credential_version) do
      call({:fence, connection_id, connection_revision, credential_version})
    end
  end

  @spec ensure_dispatchable(token()) :: :ok | {:error, Error.error()}
  def ensure_dispatchable(token) when is_map(token),
    do: call({:ensure_dispatchable, token})

  @doc """
  Runs one operation after the final generation fence.

  The operation is never retried. Its `revoked?` result lets write callers
  classify a failed send as uncertain instead of moving it to a new endpoint.
  """
  @spec dispatch(token(), (-> result)) ::
          {:ok, result, boolean()} | {:error, Error.error()}
        when result: term()
  def dispatch(token, fun) when is_map(token) and is_function(fun, 0) do
    with :ok <- call({:begin_dispatch, token}) do
      try do
        result = fun.()
        {:ok, result, call({:finish_dispatch, token})}
      rescue
        exception ->
          _ = call({:finish_dispatch, token})
          reraise exception, __STACKTRACE__
      catch
        kind, reason ->
          _ = call({:finish_dispatch, token})
          :erlang.raise(kind, reason, __STACKTRACE__)
      end
    end
  end

  @spec revoke(Connection.t() | String.t()) :: :ok
  def revoke(%Connection{id: connection_id}), do: revoke(connection_id)

  def revoke(connection_id) when is_binary(connection_id),
    do: call({:revoke, connection_id})

  @spec connection_removed(Connection.t() | String.t()) :: :ok
  def connection_removed(connection), do: revoke(connection)

  @spec expire(Connection.t() | String.t()) :: :ok
  def expire(%Connection{id: connection_id}), do: expire(connection_id)
  def expire(connection_id) when is_binary(connection_id), do: call({:expire, connection_id})

  @spec force_stop(Connection.t() | String.t()) :: :ok
  def force_stop(%Connection{id: connection_id}), do: force_stop(connection_id)

  def force_stop(connection_id) when is_binary(connection_id),
    do: call({:force_stop, connection_id})

  @spec ownership(Connection.t() | String.t()) :: [map()]
  def ownership(%Connection{id: connection_id}), do: ownership(connection_id)

  def ownership(connection_id) when is_binary(connection_id),
    do: call({:ownership, connection_id})

  @impl true
  def init(opts) do
    {:ok,
     %{
       records: %{},
       current: %{},
       generations: %{},
       ownership_barriers: %{},
       drain_timeout_ms: Keyword.get(opts, :drain_timeout_ms, @default_drain_timeout_ms)
     }}
  end

  @impl true
  def handle_call({:acquire, connection, lease, endpoint}, _from, state) do
    with :ok <- CredentialLease.require_unexpired(lease),
         :ok <- CredentialLease.validate_connection_binding(lease, connection) do
      with {:ok, ownership} <- ownership_for(connection, lease, endpoint) do
        case acquire_record(ownership, endpoint, state) do
          {:ok, record, next_state} -> {:reply, {:ok, token(record)}, next_state}
          {:error, error, next_state} -> {:reply, {:error, error}, next_state}
        end
      else
        {:error, error} -> {:reply, {:error, error}, state}
      end
    else
      {:error, %_{} = error} -> {:reply, {:error, error}, state}
    end
  end

  def handle_call({:release, token}, _from, state) do
    {:reply, :ok, update_record(token, state, &decrement_active/1)}
  end

  def handle_call({:ensure_dispatchable, token}, _from, state) do
    {:reply, dispatchable?(token, state), state}
  end

  def handle_call({:begin_dispatch, token}, _from, state) do
    case dispatchable?(token, state) do
      :ok -> {:reply, :ok, update_record(token, state, &increment_active/1)}
      error -> {:reply, error, state}
    end
  end

  def handle_call({:finish_dispatch, token}, _from, state) do
    {revoked?, state} = finish_dispatch(token, state)
    {:reply, revoked?, state}
  end

  def handle_call({:revoke, connection_id}, _from, state) do
    state = tombstone_ownership(connection_id, state)
    {:reply, :ok, retire_connection(connection_id, state, :revoked)}
  end

  def handle_call(
        {:fence, connection_id, connection_revision, credential_version},
        _from,
        state
      ) do
    case advance_fence(connection_id, connection_revision, credential_version, state) do
      {:ok, state} ->
        {:reply, :ok, retire_connection(connection_id, state, :revoked)}

      {:error, error} ->
        {:reply, {:error, error}, state}
    end
  end

  def handle_call({:expire, connection_id}, _from, state) do
    {:reply, :ok, retire_connection(connection_id, state, :expired)}
  end

  def handle_call({:force_stop, connection_id}, _from, state) do
    state =
      state.records
      |> Map.values()
      |> Enum.filter(&(&1.connection_id == connection_id))
      |> Enum.reduce(state, fn record, acc -> remove_record(record, acc) end)

    {:reply, :ok, %{state | current: Map.delete(state.current, connection_id)}}
  end

  def handle_call({:ownership, connection_id}, _from, state) do
    records =
      state.records
      |> Map.values()
      |> Enum.filter(&(&1.connection_id == connection_id))
      |> Enum.map(&public_record/1)
      |> Enum.sort_by(& &1.generation)

    {:reply, records, state}
  end

  @impl true
  def handle_info({:force_stop, key}, state) do
    case Map.fetch(state.records, key) do
      {:ok, record} -> {:noreply, remove_record(record, state)}
      :error -> {:noreply, state}
    end
  end

  def handle_info({:expire, key}, state) do
    case Map.fetch(state.records, key) do
      {:ok, record} -> {:noreply, retire_record(record, state, :expired)}
      :error -> {:noreply, state}
    end
  end

  defp acquire_record(ownership, endpoint, state) do
    with :ok <- validate_ownership_barrier(ownership, state) do
      current_key = Map.get(state.current, ownership.connection_id)

      case Map.get(state.records, current_key) do
        record when is_map(record) ->
          if same_ownership?(record, ownership) do
            record = increment_active(record)
            {:ok, record, put_in(state.records[record.key], record)}
          else
            register_new_generation(ownership, endpoint, record, state)
          end

        nil ->
          register_new_generation(ownership, endpoint, nil, state)
      end
    else
      {:error, error} -> {:error, error, state}
    end
  end

  defp register_new_generation(ownership, endpoint, old_record, state) do
    generation = next_generation(ownership.connection_id, state)
    endpoint_id = generation_endpoint_id(ownership.base_endpoint_id, generation)

    case register(endpoint_id, endpoint) do
      :ok ->
        record =
          Map.merge(ownership, %{
            key: {ownership.connection_id, generation},
            generation: generation,
            endpoint_id: endpoint_id,
            active: 1,
            status: :active
          })

        state = put_in(state.records[record.key], record)
        state = put_in(state.current[ownership.connection_id], record.key)
        state = put_in(state.generations[ownership.connection_id], generation)
        state = accept_ownership(ownership, state)
        schedule_expiry(record)
        state = if old_record, do: retire_record(old_record, state, :draining), else: state
        {:ok, record, state}

      {:error, error} ->
        {:error,
         Error.execution("MCP endpoint registration failed",
           phase: :endpoint_registration,
           details: %{reason: registration_reason(error)}
         ), state}
    end
  end

  defp register(endpoint_id, endpoint) do
    endpoint = %{endpoint | id: endpoint_id}

    case Jido.MCP.register_endpoint(endpoint) do
      {:ok, _endpoint} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp retire_connection(connection_id, state, status) do
    state = %{state | current: Map.delete(state.current, connection_id)}

    state.records
    |> Map.values()
    |> Enum.filter(&(&1.connection_id == connection_id))
    |> Enum.reduce(state, fn record, acc -> retire_record(record, acc, status) end)
  end

  defp retire_record(record, state, status) do
    record = %{record | status: status}
    state = put_in(state.records[record.key], record)

    if record.active == 0 do
      remove_record(record, state)
    else
      Process.send_after(self(), {:force_stop, record.key}, state.drain_timeout_ms)
      state
    end
  end

  defp update_record(token, state, fun) do
    case Map.fetch(state.records, record_key(token)) do
      {:ok, record} ->
        record = fun.(record)
        state = put_in(state.records[record.key], record)

        if record.active == 0 and record.status != :active,
          do: remove_record(record, state),
          else: state

      :error ->
        state
    end
  end

  defp finish_dispatch(token, state) do
    case Map.fetch(state.records, record_key(token)) do
      {:ok, record} ->
        revoked? =
          record.status != :active or Map.get(state.current, record.connection_id) != record.key

        {revoked?, update_record(token, state, &decrement_active/1)}

      :error ->
        {true, state}
    end
  end

  defp remove_record(record, state) do
    _ = Jido.MCP.unregister_endpoint(record.endpoint_id)
    state = %{state | records: Map.delete(state.records, record.key)}

    if Map.get(state.current, record.connection_id) == record.key do
      %{state | current: Map.delete(state.current, record.connection_id)}
    else
      state
    end
  end

  defp dispatchable?(token, state) do
    with {:ok, record} <- Map.fetch(state.records, record_key(token)),
         true <- record.status == :active,
         true <- Map.get(state.current, record.connection_id) == record.key,
         true <- DateTime.compare(record.expires_at, DateTime.utc_now()) == :gt do
      :ok
    else
      _ ->
        {:error,
         Error.auth("MCP endpoint lease is no longer active", reason: :mcp_endpoint_lease_revoked)}
    end
  end

  defp ownership_for(connection, lease, endpoint) do
    with {:ok, connection_revision} <- connection_revision(connection),
         {:ok, credential_version} <- credential_version(lease) do
      {:ok,
       %{
         connection_id: connection.id,
         base_endpoint_id: Jido.Connect.MCP.HostEndpoint.internal_id(connection),
         endpoint_fingerprint: endpoint_fingerprint(endpoint),
         connection_revision: connection_revision,
         credential_version: credential_version,
         expires_at: lease.expires_at
       }}
    end
  end

  defp connection_revision(connection) do
    required_version(
      connection.metadata,
      :connection_revision,
      :revision,
      "MCP connection revision is required",
      :mcp_connection_revision_required,
      connection.id
    )
  end

  defp credential_version(lease) do
    required_version(
      lease.metadata,
      :credential_version,
      :version,
      "MCP credential version is required",
      :mcp_credential_version_required,
      lease.connection_id
    )
  end

  defp required_version(metadata, primary_key, fallback_key, message, reason, connection_id) do
    case Data.get(metadata || %{}, primary_key, Data.get(metadata || %{}, fallback_key, :missing)) do
      version when is_integer(version) and version >= 0 -> {:ok, version}
      _other -> {:error, Error.auth(message, reason: reason, connection_id: connection_id)}
    end
  end

  defp endpoint_fingerprint(%Endpoint{} = endpoint) do
    endpoint
    |> endpoint_projection()
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  # Keep only values that are part of endpoint identity and cannot contain an
  # endpoint credential. Header and client option values are intentionally not
  # fingerprinted; credential rotation is represented by credential_version.
  defp endpoint_projection(%Endpoint{} = endpoint) do
    %{
      transport: transport_projection(endpoint.transport),
      protocol_version: endpoint.protocol_version,
      capabilities: endpoint.capabilities,
      request_timeout_ms: get_in(endpoint.timeouts, [:request_ms]),
      client_name: Map.get(endpoint.client_info, :name) || Map.get(endpoint.client_info, "name")
    }
  end

  defp transport_projection({:streamable_http, opts}) do
    %{
      type: :streamable_http,
      base_url: Keyword.get(opts, :base_url),
      mcp_path: Keyword.get(opts, :mcp_path),
      url: Keyword.get(opts, :url)
    }
  end

  defp transport_projection({type, _opts}), do: %{type: type}
  defp transport_projection(_transport), do: %{type: :unknown}

  defp next_generation(connection_id, state) do
    Map.get(state.generations, connection_id, 0) + 1
  end

  defp generation_endpoint_id(base_id, 1), do: base_id
  defp generation_endpoint_id(base_id, generation), do: "#{base_id}:g#{generation}"

  defp same_ownership?(record, ownership) do
    record.status == :active and
      Enum.all?([:endpoint_fingerprint, :connection_revision, :credential_version], fn key ->
        Map.fetch!(record, key) == Map.fetch!(ownership, key)
      end)
  end

  defp validate_ownership_barrier(ownership, state) do
    case Map.get(state.ownership_barriers, ownership.connection_id) do
      nil ->
        :ok

      barrier ->
        cond do
          ownership.connection_revision < barrier.connection_revision -> stale_ownership()
          ownership.credential_version < barrier.credential_version -> stale_ownership()
          newer_ownership?(ownership, barrier) -> :ok
          barrier.tombstone? -> stale_ownership()
          is_nil(barrier.endpoint_fingerprint) -> :ok
          ownership.endpoint_fingerprint == barrier.endpoint_fingerprint -> :ok
          true -> stale_ownership()
        end
    end
  end

  defp accept_ownership(ownership, state) do
    barrier = %{
      connection_revision: ownership.connection_revision,
      credential_version: ownership.credential_version,
      endpoint_fingerprint: ownership.endpoint_fingerprint,
      tombstone?: false
    }

    put_in(state.ownership_barriers[ownership.connection_id], barrier)
  end

  defp advance_fence(connection_id, connection_revision, credential_version, state) do
    case Map.get(state.ownership_barriers, connection_id) do
      nil ->
        {:ok,
         put_ownership_barrier(state, connection_id, connection_revision, credential_version)}

      barrier ->
        target = %{
          connection_revision: connection_revision,
          credential_version: credential_version
        }

        cond do
          connection_revision < barrier.connection_revision ->
            {:error, stale_fence_error()}

          credential_version < barrier.credential_version ->
            {:error, stale_fence_error()}

          pending_fence?(target, barrier) ->
            {:ok, state}

          not newer_ownership?(target, barrier) ->
            {:error, stale_fence_error()}

          true ->
            {:ok,
             put_ownership_barrier(state, connection_id, connection_revision, credential_version)}
        end
    end
  end

  defp put_ownership_barrier(state, connection_id, connection_revision, credential_version) do
    barrier = %{
      connection_revision: connection_revision,
      credential_version: credential_version,
      endpoint_fingerprint: nil,
      tombstone?: false
    }

    put_in(state.ownership_barriers[connection_id], barrier)
  end

  defp tombstone_ownership(connection_id, state) do
    Map.update(
      state,
      :ownership_barriers,
      %{},
      &Map.update(&1, connection_id, empty_tombstone(), fn barrier ->
        %{barrier | tombstone?: true}
      end)
    )
  end

  defp empty_tombstone do
    %{
      connection_revision: 0,
      credential_version: 0,
      endpoint_fingerprint: nil,
      tombstone?: true
    }
  end

  defp newer_ownership?(ownership, barrier) do
    ownership.connection_revision > barrier.connection_revision or
      ownership.credential_version > barrier.credential_version
  end

  defp pending_fence?(ownership, barrier) do
    ownership.connection_revision == barrier.connection_revision and
      ownership.credential_version == barrier.credential_version and
      is_nil(barrier.endpoint_fingerprint) and not barrier.tombstone?
  end

  defp stale_ownership, do: {:error, stale_fence_error()}

  defp stale_fence_error do
    Error.auth("MCP endpoint ownership is stale", reason: :mcp_endpoint_lease_stale)
  end

  defp fence_version(opts, key) do
    case Keyword.get(opts, key) do
      version when is_integer(version) and version >= 0 -> {:ok, version}
      _other -> {:error, stale_fence_error()}
    end
  end

  defp token(record),
    do:
      Map.take(record, [
        :connection_id,
        :endpoint_id,
        :generation,
        :endpoint_fingerprint,
        :connection_revision,
        :credential_version
      ])

  defp record_key(token), do: {Map.get(token, :connection_id), Map.get(token, :generation)}
  defp increment_active(record), do: %{record | active: record.active + 1}
  defp decrement_active(record), do: %{record | active: max(record.active - 1, 0)}

  defp public_record(record) do
    record
    |> Map.take([
      :connection_id,
      :endpoint_id,
      :generation,
      :endpoint_fingerprint,
      :connection_revision,
      :credential_version,
      :expires_at,
      :active,
      :status
    ])
  end

  defp registration_reason(reason) when is_atom(reason), do: reason
  defp registration_reason({reason, _details}) when is_atom(reason), do: reason
  defp registration_reason(_reason), do: :invalid_endpoint

  defp schedule_expiry(record) do
    timeout = max(DateTime.diff(record.expires_at, DateTime.utc_now(), :millisecond), 1)
    Process.send_after(self(), {:expire, record.key}, timeout)
  end

  defp call(message, timeout \\ 5_000) do
    ensure_started()
    GenServer.call(@name, message, timeout)
  end

  defp ensure_started do
    if is_nil(Process.whereis(@name)) do
      {:ok, _apps} = Application.ensure_all_started(:jido_connect_mcp)
    end

    :ok
  end
end
