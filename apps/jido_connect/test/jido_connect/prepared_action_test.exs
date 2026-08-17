defmodule Jido.Connect.PreparedActionTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.RuntimeFixtures

  defmodule Handler do
    def run(%{repo: repo}, %{context: %{metadata: %{test_pid: test_pid}}} = runtime) do
      send(test_pid, {:handler_called, repo})
      send(test_pid, {:handler_execution, Map.get(runtime, :execution)})
      {:ok, %{repo: repo}}
    end
  end

  defmodule Preview do
    @behaviour Jido.Connect.ActionPreview

    @impl true
    def preview(%{repo: repo}, %{action_id: action_id}) do
      %{
        repository: repo,
        action: action_id,
        api_token: "must-not-leak"
      }
    end
  end

  defmodule InvalidPreview do
    @behaviour Jido.Connect.ActionPreview

    @impl true
    def preview(_input, _context), do: :invalid
  end

  setup do
    spec =
      RuntimeFixtures.spec(%{
        action: %{
          handler: Handler,
          mutation?: true,
          risk: :write,
          confirmation: :always
        }
      })

    {context, lease} = RuntimeFixtures.context_and_lease()
    context = %{context | metadata: %{test_pid: self()}}

    %{spec: spec, context: context, lease: lease, input: %{repo: "agentjido/jido_connect"}}
  end

  test "prepare does not call the handler and commit calls it once", state do
    assert {:ok, prepared} = prepare(state)
    refute_received {:handler_called, _repo}

    authorization = %{plan_id: prepared.id, approved_by: "user_1"}

    assert {:ok, %{repo: "agentjido/jido_connect"}} =
             commit(state, prepared, authorization)

    assert_received {:handler_called, "agentjido/jido_connect"}
    refute_received {:handler_called, _repo}
  end

  test "commit requires host evidence and a validator", state do
    assert {:ok, prepared} = prepare(state)

    assert {:error, %Connect.Error.AuthError{reason: :execution_authorization_required}} =
             Connect.commit(state.spec, prepared, state.input,
               context: state.context,
               credential_lease: state.lease,
               binding_ref: "binding_1"
             )

    assert {:error, %Connect.Error.AuthError{reason: :execution_authorization_required}} =
             commit(state, prepared, true)

    assert {:error, %Connect.Error.AuthError{reason: :authorization_validator_required}} =
             Connect.commit(state.spec, prepared, state.input,
               context: state.context,
               credential_lease: state.lease,
               binding_ref: "binding_1",
               execution_authorization: %{plan_id: prepared.id}
             )

    refute_received {:handler_called, _repo}
  end

  test "commit rejects input, binding, and credential revision changes", state do
    assert {:ok, prepared} = prepare(state)
    authorization = %{plan_id: prepared.id}

    assert_stale(
      Connect.commit(
        state.spec,
        prepared,
        %{repo: "different/repo"},
        commit_opts(state, authorization)
      ),
      :input_hash
    )

    assert_stale(
      Connect.commit(
        state.spec,
        prepared,
        state.input,
        Keyword.put(commit_opts(state, authorization), :binding_ref, "binding_2")
      ),
      :binding_hash
    )

    changed_lease = %{state.lease | metadata: %{credential_version: 2}}

    assert_stale(
      Connect.commit(
        state.spec,
        prepared,
        state.input,
        Keyword.put(commit_opts(state, authorization), :credential_lease, changed_lease)
      ),
      :lease_hash
    )

    refute_received {:handler_called, _repo}
  end

  test "commit rejects an expired prepared action", state do
    now = DateTime.utc_now()
    lease = %{state.lease | expires_at: DateTime.add(now, 60, :second)}

    assert {:ok, prepared} =
             Connect.prepare(state.spec, "demo.repo.show", state.input,
               context: state.context,
               credential_lease: lease,
               binding_ref: "binding_1",
               prepare_ttl_ms: 1_000,
               now: now
             )

    assert {:error, %Connect.Error.AuthError{reason: :prepared_action_expired}} =
             Connect.commit(state.spec, prepared, state.input,
               context: state.context,
               credential_lease: lease,
               binding_ref: "binding_1",
               now: DateTime.add(now, 1, :second)
             )

    refute_received {:handler_called, _repo}
  end

  test "direct mutation invocation can be denied", state do
    assert {:error, %Connect.Error.AuthError{reason: :execution_authorization_required}} =
             Connect.invoke(state.spec, "demo.repo.show", state.input,
               context: state.context,
               credential_lease: state.lease,
               direct_mutation_mode: :deny
             )

    refute_received {:handler_called, _repo}
  end

  test "reads stay direct and required-for-AI depends on the actor", state do
    read_spec = RuntimeFixtures.spec()

    assert {:ok, %{repo: "agentjido/jido_connect"}} =
             Connect.invoke(read_spec, "demo.repo.show", state.input,
               context: state.context,
               credential_lease: state.lease,
               direct_mutation_mode: :deny
             )

    ai_spec =
      RuntimeFixtures.spec(%{
        action: %{
          handler: Handler,
          mutation?: true,
          risk: :write,
          confirmation: :required_for_ai
        }
      })

    assert {:ok, user_prepared} =
             Connect.prepare(ai_spec, "demo.repo.show", state.input,
               context: state.context,
               credential_lease: state.lease
             )

    refute user_prepared.confirmation_required?

    ai_context = %{state.context | actor: %{id: "persona_1", type: :agent}}

    assert {:ok, ai_prepared} =
             Connect.prepare(ai_spec, "demo.repo.show", state.input,
               context: ai_context,
               credential_lease: state.lease
             )

    assert ai_prepared.confirmation_required?
  end

  test "destructive risk always requires confirmation", state do
    destructive_spec = RuntimeFixtures.spec(%{action: %{risk: :destructive}})

    assert {:ok, prepared} =
             Connect.prepare(destructive_spec, "demo.repo.show", state.input,
               context: state.context,
               credential_lease: state.lease
             )

    assert prepared.confirmation_required?
  end

  test "provider previews are pure, useful, and sanitized", state do
    spec =
      RuntimeFixtures.spec(%{
        action: %{
          handler: Handler,
          preview: Preview,
          mutation?: true,
          risk: :write,
          confirmation: :always
        }
      })

    assert {:ok, prepared} = prepare(%{state | spec: spec})

    assert prepared.preview["repository"] == "agentjido/jido_connect"
    assert prepared.preview["action"] == "demo.repo.show"
    assert prepared.preview["api_token"] == "[redacted]"
    assert prepared.preview.action_id == "demo.repo.show"
    assert prepared.preview.connection.id == "conn_1"
    refute_received {:handler_called, _repo}
  end

  test "prepare rejects invalid provider preview results", state do
    spec = RuntimeFixtures.spec(%{action: %{preview: InvalidPreview}})

    assert {:error, %Connect.Error.ExecutionError{phase: :preview}} =
             prepare(%{state | spec: spec})

    refute_received {:handler_called, _repo}
  end

  test "the prepared value does not retain input or credential fields", state do
    secret_lease = %{state.lease | fields: %{access_token: "secret-value"}}

    assert {:ok, prepared} =
             prepare(%{state | lease: secret_lease, input: %{repo: "private/repository"}})

    rendered = inspect(prepared)
    public = inspect(Connect.PreparedAction.to_public_map(prepared))

    refute rendered =~ "private/repository"
    refute rendered =~ "secret-value"
    refute public =~ "private/repository"
    refute public =~ "secret-value"
    assert prepared.preview.input_fields == ["repo"]
    assert prepared.preview.connection.id == "conn_1"
  end

  test "dump and load survive a JSON storage round trip", state do
    stored_state = %{
      state
      | input: %{repo: "private/repository"},
        lease: %{state.lease | fields: %{access_token: "secret-value"}}
    }

    assert {:ok, prepared} = prepare(stored_state)

    dump = Connect.PreparedAction.dump(prepared)
    encoded = Jason.encode!(dump)
    decoded = Jason.decode!(encoded)

    refute encoded =~ "private/repository"
    refute encoded =~ "secret-value"
    assert decoded["version"] == Connect.PreparedAction.format_version()

    assert {:ok, loaded} = Connect.PreparedAction.load(decoded)
    assert Connect.PreparedAction.dump(loaded) == decoded
    assert loaded.prepared_at == prepared.prepared_at
    assert loaded.expires_at == prepared.expires_at

    assert {:ok, %{repo: "private/repository"}} =
             commit(stored_state, loaded, %{plan_id: loaded.id})

    assert_received {:handler_called, "private/repository"}
  end

  test "load rejects unknown versions and malformed dumps", state do
    assert {:ok, prepared} = prepare(state)
    dump = Connect.PreparedAction.dump(prepared)

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :unsupported_prepared_action_version,
              subject: 2
            }} = Connect.PreparedAction.load(Map.put(dump, "version", 2))

    assert {:error,
            %Connect.Error.ValidationError{
              reason: :invalid_prepared_action_dump,
              details: %{field: :expires_at}
            }} = Connect.PreparedAction.load(Map.put(dump, "expires_at", "not-a-date"))
  end

  test "commit freezes the execution and idempotency identifiers", state do
    assert {:ok, prepared} =
             Connect.prepare(state.spec, "demo.repo.show", state.input,
               context: state.context,
               credential_lease: state.lease,
               binding_ref: "binding_1",
               execution_id: "execution_1",
               idempotency_key: "idempotency_1"
             )

    authorization = %{plan_id: prepared.id}

    assert_stale(
      Connect.commit(
        state.spec,
        prepared,
        state.input,
        commit_opts(state, authorization) ++ [idempotency_key: "idempotency_1"]
      ),
      :execution_id
    )

    assert {:ok, _output} =
             Connect.commit(
               state.spec,
               prepared,
               state.input,
               commit_opts(state, authorization) ++
                 [execution_id: "execution_1", idempotency_key: "idempotency_1"]
             )

    assert_received {:handler_execution,
                     %{
                       id: "execution_1",
                       idempotency_key: "idempotency_1",
                       prepared_action_id: prepared_id
                     }}

    assert prepared_id == prepared.id
  end

  defp prepare(state) do
    Connect.prepare(state.spec, "demo.repo.show", state.input,
      context: state.context,
      credential_lease: state.lease,
      binding_ref: "binding_1"
    )
  end

  defp commit(state, prepared, authorization) do
    Connect.commit(
      state.spec,
      prepared,
      state.input,
      commit_opts(state, authorization)
    )
  end

  defp commit_opts(state, authorization) do
    [
      context: state.context,
      credential_lease: state.lease,
      binding_ref: "binding_1",
      execution_authorization: authorization,
      authorization_validator: fn evidence, prepared, _context ->
        evidence.plan_id == prepared.id
      end
    ]
  end

  defp assert_stale(result, field) do
    assert {:error,
            %Connect.Error.AuthError{
              reason: :prepared_action_stale,
              details: %{changed: ^field}
            }} = result
  end
end
