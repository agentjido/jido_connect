defmodule Jido.Connect.MCP.EndpointLeaseManagerTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.MCP.{ClientSource, Endpoint, EndpointLeaseManager}

  defmodule LeaseClient do
    @behaviour Jido.Connect.MCP.Client

    def list_tools(_client, _opts), do: {:ok, %{"tools" => []}}
    def call_tool(_client, _name, _arguments, _opts), do: {:ok, %{"content" => []}}
  end

  setup do
    connection = connection("lease-manager-#{System.unique_integer([:positive])}")
    on_exit(fn -> EndpointLeaseManager.force_stop(connection) end)
    %{connection: connection}
  end

  test "reuses one registered endpoint for matching ownership", %{connection: connection} do
    lease = lease(connection, 1, "secret-one")
    endpoint = endpoint("secret-one")

    assert {:ok, first} = EndpointLeaseManager.acquire(connection, lease, endpoint)
    assert {:ok, second} = EndpointLeaseManager.acquire(connection, lease, endpoint)
    assert first.endpoint_id == second.endpoint_id
    assert first.generation == second.generation
    assert [ownership] = EndpointLeaseManager.ownership(connection)
    assert ownership.active == 2

    :ok = EndpointLeaseManager.release(first)
    :ok = EndpointLeaseManager.release(second)
  end

  test "identical connection ids in different tenants keep separate clients and revocation", %{
    connection: first_connection
  } do
    second_connection = %{
      first_connection
      | tenant_id: "tenant_2",
        owner_id: "tenant_2"
    }

    on_exit(fn -> EndpointLeaseManager.force_stop(second_connection) end)
    source = endpoint("same-secret")

    assert {:ok, first} =
             EndpointLeaseManager.acquire(
               first_connection,
               lease(first_connection, 1, "same-secret"),
               source
             )

    assert {:ok, second} =
             EndpointLeaseManager.acquire(
               second_connection,
               lease(second_connection, 1, "same-secret"),
               source
             )

    refute first.endpoint_id == second.endpoint_id
    assert first.tenant_id == "tenant_1"
    assert second.tenant_id == "tenant_2"
    assert [%{tenant_id: "tenant_1"}] = EndpointLeaseManager.ownership(first_connection)
    assert [%{tenant_id: "tenant_2"}] = EndpointLeaseManager.ownership(second_connection)

    assert :ok = EndpointLeaseManager.revoke(first_connection)

    assert {:error, %Connect.Error.AuthError{reason: :mcp_endpoint_lease_revoked}} =
             EndpointLeaseManager.ensure_dispatchable(first)

    assert :ok = EndpointLeaseManager.ensure_dispatchable(second)
    :ok = EndpointLeaseManager.release(first)
    assert [] = EndpointLeaseManager.ownership(first_connection)
    assert [%{status: :active}] = EndpointLeaseManager.ownership(second_connection)

    :ok = EndpointLeaseManager.release(second)
  end

  test "connection lifecycle changes stay within one tenant" do
    for action <- [:fence, :expire, :force_stop] do
      id = "shared-#{action}-#{System.unique_integer([:positive])}"
      first_connection = connection(id)
      second_connection = %{first_connection | tenant_id: "tenant_2", owner_id: "tenant_2"}
      source = endpoint("same-secret")

      assert {:ok, first} =
               EndpointLeaseManager.acquire(
                 first_connection,
                 lease(first_connection, 1, "same-secret"),
                 source
               )

      assert {:ok, second} =
               EndpointLeaseManager.acquire(
                 second_connection,
                 lease(second_connection, 1, "same-secret"),
                 source
               )

      case action do
        :fence ->
          assert :ok =
                   EndpointLeaseManager.fence(first_connection,
                     connection_revision: 8,
                     credential_version: 2
                   )

        :expire ->
          assert :ok = EndpointLeaseManager.expire(first_connection)

        :force_stop ->
          assert :ok = EndpointLeaseManager.force_stop(first_connection)
      end

      assert {:error, %Connect.Error.AuthError{reason: :mcp_endpoint_lease_revoked}} =
               EndpointLeaseManager.ensure_dispatchable(first)

      assert :ok = EndpointLeaseManager.ensure_dispatchable(second)

      assert [%{tenant_id: "tenant_2", status: :active}] =
               EndpointLeaseManager.ownership(second_connection)

      assert :ok = EndpointLeaseManager.release(first)
      assert :ok = EndpointLeaseManager.release(second)
      assert :ok = EndpointLeaseManager.force_stop(first_connection)
      assert :ok = EndpointLeaseManager.force_stop(second_connection)
    end
  end

  test "lifecycle calls require a tenant-qualified connection", %{connection: connection} do
    assert {:ok, token} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one"),
               endpoint("secret-one")
             )

    for result <- [
          EndpointLeaseManager.revoke(connection.id),
          EndpointLeaseManager.expire(connection.id),
          EndpointLeaseManager.force_stop(connection.id),
          EndpointLeaseManager.ownership(connection.id),
          EndpointLeaseManager.fence(connection.id,
            connection_revision: 8,
            credential_version: 2
          )
        ] do
      assert {:error, %Connect.Error.ValidationError{reason: :invalid_mcp_connection_key}} =
               result
    end

    assert :ok = EndpointLeaseManager.ensure_dispatchable(token)

    assert [%{tenant_id: "tenant_1"}] =
             EndpointLeaseManager.ownership({"tenant_1", connection.id})

    assert :ok = EndpointLeaseManager.release(token)
  end

  test "binds one live tool schema hash to each endpoint generation", %{connection: connection} do
    assert {:ok, first} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one"),
               endpoint("secret-one")
             )

    assert :ok = EndpointLeaseManager.bind_schema(first, "trelloReadBoard", "hash-one")
    assert :ok = EndpointLeaseManager.bind_schema(first, "trelloReadBoard", "hash-one")

    assert {:error, %Connect.Error.ValidationError{reason: :mcp_tool_schema_changed}} =
             EndpointLeaseManager.bind_schema(first, "trelloReadBoard", "hash-two")

    rotated = put_in(connection.metadata[:connection_revision], 8)

    assert {:ok, second} =
             EndpointLeaseManager.acquire(
               rotated,
               lease(rotated, 2, "secret-two"),
               endpoint("secret-two")
             )

    assert :ok = EndpointLeaseManager.bind_schema(second, "trelloReadBoard", "hash-two")

    :ok = EndpointLeaseManager.release(first)
    :ok = EndpointLeaseManager.release(second)
  end

  test "reused ownership refreshes expiry and ignores the stale timer", %{
    connection: connection
  } do
    first_expiry = DateTime.add(DateTime.utc_now(), 60, :second)
    renewed_expiry = DateTime.add(first_expiry, 60, :second)

    assert {:ok, first} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one", first_expiry),
               endpoint("secret-one")
             )

    first_record =
      EndpointLeaseManager
      |> :sys.get_state()
      |> Map.fetch!(:records)
      |> Map.fetch!({connection.tenant_id, connection.id, first.generation})

    assert {:ok, renewed} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one", renewed_expiry),
               endpoint("secret-one")
             )

    assert renewed.endpoint_id == first.endpoint_id
    assert [%{expires_at: ^renewed_expiry}] = EndpointLeaseManager.ownership(connection)

    send(
      EndpointLeaseManager,
      {:expire, {connection.tenant_id, connection.id, renewed.generation},
       first_record.expiry_token}
    )

    assert :ok = EndpointLeaseManager.ensure_dispatchable(renewed)

    :ok = EndpointLeaseManager.release(first)
    :ok = EndpointLeaseManager.release(renewed)
  end

  test "renewing a generation does not extend an earlier token", %{connection: connection} do
    first_expiry = DateTime.add(DateTime.utc_now(), 2, :second)
    renewed_expiry = DateTime.add(first_expiry, 60, :second)
    source = endpoint("secret-one")

    assert {:ok, first} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one", first_expiry),
               source
             )

    assert {:ok, renewed} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one", renewed_expiry),
               source
             )

    assert first.endpoint_id == renewed.endpoint_id
    assert first.expires_at == first_expiry
    assert renewed.expires_at == renewed_expiry
    assert :ok = EndpointLeaseManager.ensure_dispatchable(first)
    assert :ok = EndpointLeaseManager.ensure_dispatchable(renewed)

    parent = self()

    in_flight =
      Task.async(fn ->
        EndpointLeaseManager.dispatch(first, fn ->
          send(parent, :send_started)

          receive do
            :finish_send -> {:error, :connection_lost}
          end
        end)
      end)

    assert_receive :send_started

    Process.sleep(max(DateTime.diff(first_expiry, DateTime.utc_now(), :millisecond) + 30, 0))

    send(in_flight.pid, :finish_send)
    assert {:ok, {:error, :connection_lost}, true} = Task.await(in_flight)

    assert {:error, %Connect.Error.AuthError{reason: :mcp_endpoint_lease_revoked}} =
             EndpointLeaseManager.ensure_dispatchable(first)

    assert :ok = EndpointLeaseManager.ensure_dispatchable(renewed)

    assert {:error, %Connect.Error.AuthError{reason: :mcp_endpoint_lease_revoked}} =
             EndpointLeaseManager.dispatch(first, fn ->
               send(self(), :expired_token_dispatched)
             end)

    refute_received :expired_token_dispatched
    assert [%{expires_at: ^renewed_expiry}] = EndpointLeaseManager.ownership(connection)

    assert :ok = EndpointLeaseManager.release(first)
    assert :ok = EndpointLeaseManager.release(renewed)
  end

  test "rotation fences the old generation before its client is removed", %{
    connection: connection
  } do
    assert {:ok, old} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one"),
               endpoint("secret-one")
             )

    assert {:ok, replacement} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 2, "secret-two"),
               endpoint("secret-two")
             )

    assert replacement.generation == old.generation + 1
    refute replacement.endpoint_id == old.endpoint_id

    assert {:error, %Connect.Error.AuthError{reason: :mcp_endpoint_lease_revoked}} =
             EndpointLeaseManager.ensure_dispatchable(old)

    assert [old_record, replacement_record] = EndpointLeaseManager.ownership(connection)
    assert old_record.status == :draining
    assert replacement_record.status == :active

    :ok = EndpointLeaseManager.release(old)
    assert [%{endpoint_id: replacement_id}] = EndpointLeaseManager.ownership(connection)
    assert replacement_id == replacement.endpoint_id
    assert :ok = EndpointLeaseManager.ensure_dispatchable(replacement)
    :ok = EndpointLeaseManager.release(replacement)
  end

  test "an older ownership cannot return after a newer generation", %{
    connection: connection
  } do
    assert {:ok, old} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one"),
               endpoint("secret-one")
             )

    current_connection = put_in(connection.metadata[:connection_revision], 8)

    assert {:ok, current} =
             EndpointLeaseManager.acquire(
               current_connection,
               lease(current_connection, 2, "secret-two"),
               endpoint("secret-two")
             )

    assert {:error, %Connect.Error.AuthError{reason: :mcp_endpoint_lease_stale}} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one"),
               endpoint("secret-one")
             )

    :ok = EndpointLeaseManager.release(old)
    :ok = EndpointLeaseManager.release(current)
  end

  test "connection and credential versions are monotonic independently", %{
    connection: connection
  } do
    current_connection = put_in(connection.metadata[:connection_revision], 8)

    assert {:ok, current} =
             EndpointLeaseManager.acquire(
               current_connection,
               lease(current_connection, 2, "secret-two"),
               endpoint("secret-two")
             )

    older_connection = put_in(connection.metadata[:connection_revision], 7)

    assert {:error, %Connect.Error.AuthError{reason: :mcp_endpoint_lease_stale}} =
             EndpointLeaseManager.acquire(
               older_connection,
               lease(older_connection, 3, "secret-three"),
               endpoint("secret-three")
             )

    newer_connection = put_in(connection.metadata[:connection_revision], 9)

    assert {:error, %Connect.Error.AuthError{reason: :mcp_endpoint_lease_stale}} =
             EndpointLeaseManager.acquire(
               newer_connection,
               lease(newer_connection, 1, "secret-one"),
               endpoint("secret-one")
             )

    :ok = EndpointLeaseManager.release(current)
  end

  test "a mutation fence rejects late old ownership before the replacement arrives", %{
    connection: connection
  } do
    assert {:ok, old} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one"),
               endpoint("secret-one")
             )

    assert :ok =
             EndpointLeaseManager.fence(connection,
               connection_revision: 8,
               credential_version: 2
             )

    assert {:error, %Connect.Error.AuthError{reason: :mcp_endpoint_lease_revoked}} =
             EndpointLeaseManager.ensure_dispatchable(old)

    :ok = EndpointLeaseManager.release(old)

    assert {:error, %Connect.Error.AuthError{reason: :mcp_endpoint_lease_stale}} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one"),
               endpoint("secret-one")
             )

    current_connection = put_in(connection.metadata[:connection_revision], 8)

    assert {:ok, replacement} =
             EndpointLeaseManager.acquire(
               current_connection,
               lease(current_connection, 2, "secret-two"),
               endpoint("secret-two")
             )

    :ok = EndpointLeaseManager.release(replacement)
  end

  test "a pending mutation fence is idempotent for a database retry", %{connection: connection} do
    assert {:ok, old} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one"),
               endpoint("secret-one")
             )

    ownership = [connection_revision: 8, credential_version: 2]

    assert :ok = EndpointLeaseManager.fence(connection, ownership)
    assert :ok = EndpointLeaseManager.fence(connection, ownership)

    assert {:error, %Connect.Error.AuthError{reason: :mcp_endpoint_lease_revoked}} =
             EndpointLeaseManager.ensure_dispatchable(old)

    :ok = EndpointLeaseManager.release(old)
  end

  test "revocation leaves a tombstone for the revoked ownership", %{connection: connection} do
    assert {:ok, token} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one"),
               endpoint("secret-one")
             )

    assert :ok = EndpointLeaseManager.revoke(connection)
    :ok = EndpointLeaseManager.release(token)

    assert {:error, %Connect.Error.AuthError{reason: :mcp_endpoint_lease_stale}} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one"),
               endpoint("secret-one")
             )
  end

  test "revocation during a possible send has one uncertain attempt and no retry", %{
    connection: connection
  } do
    assert {:ok, token} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one"),
               endpoint("secret-one")
             )

    parent = self()

    task =
      Task.async(fn ->
        EndpointLeaseManager.dispatch(token, fn ->
          send(parent, :send_started)

          receive do
            :finish_send -> {:error, :connection_lost}
          end
        end)
      end)

    assert_receive :send_started
    assert :ok = EndpointLeaseManager.revoke(connection)
    send(task.pid, :finish_send)
    assert {:ok, {:error, :connection_lost}, true} = Task.await(task)
    :ok = EndpointLeaseManager.release(token)
    assert [] = EndpointLeaseManager.ownership(connection)
  end

  test "ownership evidence contains no endpoint credential", %{connection: connection} do
    secret = "credential-marker-do-not-persist"

    assert {:ok, _token} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, secret),
               endpoint(secret)
             )

    assert [ownership] = EndpointLeaseManager.ownership(connection)
    refute inspect(ownership) =~ secret
    assert ownership.connection_revision == 7
    assert ownership.credential_version == 1
    assert String.match?(ownership.endpoint_fingerprint, ~r/\A[0-9a-f]{64}\z/)
  end

  test "a lease without a credential version cannot reuse an authenticated endpoint", %{
    connection: connection
  } do
    assert {:ok, first} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one"),
               endpoint("secret-one")
             )

    unversioned =
      Connect.CredentialLease.from_connection!(
        connection,
        %{mcp_endpoint: endpoint_source("secret-two")},
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second)
      )

    assert {:error, %Connect.Error.AuthError{reason: :mcp_credential_version_required}} =
             EndpointLeaseManager.acquire(connection, unversioned, endpoint("secret-two"))

    assert [ownership] = EndpointLeaseManager.ownership(connection)
    assert ownership.endpoint_id == first.endpoint_id
    assert ownership.credential_version == 1
  end

  test "a connection without a revision cannot acquire an authenticated endpoint", %{
    connection: connection
  } do
    unrevisioned = %{connection | metadata: %{}}

    assert {:error, %Connect.Error.AuthError{reason: :mcp_connection_revision_required}} =
             EndpointLeaseManager.acquire(
               unrevisioned,
               lease(unrevisioned, 1, "secret-one"),
               endpoint("secret-one")
             )

    assert [] = EndpointLeaseManager.ownership(unrevisioned)
  end

  test "connection removal unregisters every endpoint generation", %{connection: connection} do
    assert {:ok, token} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one"),
               endpoint("secret-one")
             )

    assert :ok = EndpointLeaseManager.connection_removed(connection)

    assert {:error, %Connect.Error.AuthError{reason: :mcp_endpoint_lease_revoked}} =
             EndpointLeaseManager.ensure_dispatchable(token)

    :ok = EndpointLeaseManager.release(token)
    assert [] = EndpointLeaseManager.ownership(connection)
  end

  test "expiry fences a generation before it unregisters the client", %{connection: connection} do
    assert {:ok, token} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one"),
               endpoint("secret-one")
             )

    assert :ok = EndpointLeaseManager.expire(connection)

    assert {:error, %Connect.Error.AuthError{reason: :mcp_endpoint_lease_revoked}} =
             EndpointLeaseManager.ensure_dispatchable(token)

    :ok = EndpointLeaseManager.release(token)
    assert [] = EndpointLeaseManager.ownership(connection)
  end

  test "an expired lease is rejected before endpoint registration", %{connection: connection} do
    expired =
      Connect.CredentialLease.from_connection!(
        connection,
        %{mcp_endpoint: endpoint_source("expired-secret")},
        expires_at: DateTime.add(DateTime.utc_now(), -1, :second),
        metadata: %{credential_version: 1}
      )

    assert {:error, %Connect.Error.AuthError{reason: :credential_lease_expired}} =
             EndpointLeaseManager.acquire(connection, expired, endpoint("expired-secret"))

    assert [] = EndpointLeaseManager.ownership(connection)
  end

  test "force stop removes an endpoint that does not drain", %{connection: connection} do
    assert {:ok, token} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one"),
               endpoint("secret-one")
             )

    parent = self()

    task =
      Task.async(fn ->
        EndpointLeaseManager.dispatch(token, fn ->
          send(parent, :send_started)

          receive do
            :finish_send -> {:error, :connection_lost}
          end
        end)
      end)

    assert_receive :send_started
    assert :ok = EndpointLeaseManager.force_stop(connection)
    assert [] = EndpointLeaseManager.ownership(connection)
    send(task.pid, :finish_send)
    assert {:ok, {:error, :connection_lost}, true} = Task.await(task)
  end

  test "dispatch cleanup runs when the operation raises", %{connection: connection} do
    assert {:ok, token} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one"),
               endpoint("secret-one")
             )

    assert_raise RuntimeError, "send failed", fn ->
      EndpointLeaseManager.dispatch(token, fn -> raise "send failed" end)
    end

    assert [%{active: 1}] = EndpointLeaseManager.ownership(connection)
    assert :ok = EndpointLeaseManager.revoke(connection)
    assert :ok = EndpointLeaseManager.release(token)
    assert [] = EndpointLeaseManager.ownership(connection)
  end

  test "generation does not reset after an endpoint is removed", %{connection: connection} do
    assert {:ok, first} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one"),
               endpoint("secret-one")
             )

    assert :ok = EndpointLeaseManager.force_stop(connection)

    assert {:ok, second} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 2, "secret-two"),
               endpoint("secret-two")
             )

    assert second.generation == first.generation + 1
  end

  test "does not stop a host-owned client reference", %{connection: connection} do
    client = start_supervised!({Agent, fn -> :ready end})
    source = %{endpoint("secret-one") | ref: client}

    assert {:ok, token} =
             EndpointLeaseManager.acquire(
               connection,
               lease(connection, 1, "secret-one"),
               source
             )

    assert token.client_ref == client
    assert :ok = EndpointLeaseManager.force_stop(connection)
    assert Process.alive?(client)
  end

  defp connection(id) do
    Connect.Connection.new!(%{
      id: id,
      provider: :mcp,
      profile: :endpoint,
      tenant_id: "tenant_1",
      owner_type: :tenant,
      owner_id: "tenant_1",
      status: :connected,
      metadata: %{connection_revision: 7}
    })
  end

  defp lease(connection, version, secret) do
    lease(connection, version, secret, DateTime.add(DateTime.utc_now(), 300, :second))
  end

  defp lease(connection, version, secret, expires_at) do
    Connect.CredentialLease.from_connection!(
      connection,
      %{mcp_endpoint: endpoint_source(secret)},
      expires_at: expires_at,
      metadata: %{credential_version: version}
    )
  end

  defp endpoint(secret) do
    {:ok, endpoint} = Endpoint.new("temporary", endpoint_source(secret))

    %ClientSource{
      module: LeaseClient,
      ref: :lease_test_client,
      endpoint: endpoint,
      ownership: :host
    }
  end

  defp endpoint_source(secret) do
    %{
      transport:
        {:streamable_http,
         [url: "https://mcp.example.test/mcp", headers: [{"authorization", "Bearer #{secret}"}]]},
      client_info: %{name: "endpoint-lease-test"}
    }
  end
end
