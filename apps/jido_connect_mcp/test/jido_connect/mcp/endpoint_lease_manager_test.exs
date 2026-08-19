defmodule Jido.Connect.MCP.EndpointLeaseManagerTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.MCP.EndpointLeaseManager

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

    assert {:ok, _endpoint} = Jido.MCP.ClientPool.fetch_endpoint(old.endpoint_id)
    assert {:ok, _endpoint} = Jido.MCP.ClientPool.fetch_endpoint(replacement.endpoint_id)

    :ok = EndpointLeaseManager.release(old)
    assert {:error, :unknown_endpoint} = Jido.MCP.ClientPool.fetch_endpoint(old.endpoint_id)
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
    assert {:error, :unknown_endpoint} = Jido.MCP.ClientPool.fetch_endpoint(token.endpoint_id)
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
    assert {:error, :unknown_endpoint} = Jido.MCP.ClientPool.fetch_endpoint(token.endpoint_id)
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
    assert {:error, :unknown_endpoint} = Jido.MCP.ClientPool.fetch_endpoint(token.endpoint_id)
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
    assert {:error, :unknown_endpoint} = Jido.MCP.ClientPool.fetch_endpoint(token.endpoint_id)
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
    assert {:error, :unknown_endpoint} = Jido.MCP.ClientPool.fetch_endpoint(token.endpoint_id)
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
    Connect.CredentialLease.from_connection!(
      connection,
      %{mcp_endpoint: endpoint_source(secret)},
      expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
      metadata: %{credential_version: version}
    )
  end

  defp endpoint(secret) do
    {:ok, endpoint} = Jido.MCP.Endpoint.new("temporary", endpoint_source(secret))
    endpoint
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
