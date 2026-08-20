defmodule Jido.Connect.Runtime.ApiTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.RuntimeFixtures

  test "top-level API accepts provider modules or compiled specs" do
    spec = RuntimeFixtures.spec()
    {context, lease} = RuntimeFixtures.context_and_lease()

    assert {:ok, ^spec} = Connect.spec(spec)
    assert {:ok, ^spec} = Connect.spec(RuntimeFixtures.Integration)
    assert {:ok, [%{id: "demo.repo.show"}]} = Connect.actions(RuntimeFixtures.Integration)
    assert {:ok, [%{id: "demo.repo.changed"}]} = Connect.triggers(RuntimeFixtures.Integration)
    assert {:ok, [%{id: :user}]} = Connect.auth_profiles(RuntimeFixtures.Integration)

    assert {:ok, %{id: "demo.repo.show"}} =
             Connect.action(RuntimeFixtures.Integration, "demo.repo.show")

    assert {:ok, %{id: "demo.repo.changed"}} =
             Connect.trigger(RuntimeFixtures.Integration, "demo.repo.changed")

    assert {:ok, %{repo: "org/repo"}} =
             Connect.invoke(
               RuntimeFixtures.Integration,
               "demo.repo.show",
               %{repo: "org/repo"},
               %{context: context, credential_lease: lease}
             )

    assert {:ok, %{signals: [%{repo: "org/repo"}], checkpoint: "next"}} =
             Connect.poll(
               RuntimeFixtures.Integration,
               "demo.repo.changed",
               %{repo: "org/repo"},
               %{context: context, credential_lease: lease}
             )

    assert {:error, %Connect.Error.ValidationError{reason: :unknown_integration}} =
             Connect.spec(Module.concat(__MODULE__, MissingIntegration))

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_integration}} =
             Connect.spec(RuntimeFixtures.InvalidIntegration)

    assert {:error, %Connect.Error.ExecutionError{phase: :provider_integration}} =
             Connect.spec(RuntimeFixtures.RaisingIntegration)

    assert {:ok, %Connect.Catalog.Manifest{id: :demo}} =
             Connect.Provider.manifest(RuntimeFixtures.Integration)

    assert {:ok, %{actions: [], sensors: [], plugin: nil}} =
             Connect.Provider.generated_modules(RuntimeFixtures.Integration)

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_provider_manifest}} =
             Connect.Provider.manifest(RuntimeFixtures.BadManifestProvider)

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_provider_modules}} =
             Connect.Provider.generated_modules(RuntimeFixtures.BadModulesProvider)

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_action_id}} =
             Connect.action(RuntimeFixtures.Integration, :not_a_string)

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_trigger_id}} =
             Connect.trigger(RuntimeFixtures.Integration, :not_a_string)

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_action_id}} =
             Connect.invoke(RuntimeFixtures.Integration, :not_a_string, %{})

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_invocation}} =
             Connect.invoke(RuntimeFixtures.Integration, "demo.repo.show", [])

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_trigger_id}} =
             Connect.poll(RuntimeFixtures.Integration, :not_a_string, %{})

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_poll}} =
             Connect.poll(RuntimeFixtures.Integration, "demo.repo.changed", [])
  end

  test "lookup, invoke, poll, and auth failures return structured errors" do
    spec = RuntimeFixtures.spec()
    {context, lease} = RuntimeFixtures.context_and_lease()

    assert {:ok, %{id: "demo.repo.show"}} = Connect.action(spec, "demo.repo.show")
    assert {:ok, %{id: "demo.repo.changed"}} = Connect.trigger(spec, "demo.repo.changed")

    assert {:error, %Connect.Error.ValidationError{reason: :unknown_action}} =
             Connect.action(spec, "missing")

    assert {:error, %Connect.Error.ValidationError{reason: :unknown_trigger}} =
             Connect.trigger(spec, "missing")

    assert {:ok, %{repo: "org/repo"}} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"},
               context: context,
               credential_lease: lease
             )

    assert {:ok, %{signals: [%{repo: "org/repo"}], checkpoint: "cursor"}} =
             Connect.poll(spec, "demo.repo.changed", %{repo: "org/repo"},
               context: context,
               credential_lease: lease,
               checkpoint: "cursor"
             )

    assert {:ok, %{repo: "org/repo"}} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"},
               context: Map.from_struct(context),
               credential_lease: Map.from_struct(lease)
             )

    assert {:error, %Connect.Error.AuthError{reason: :credential_lease_required}} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"}, context: context)

    assert {:error, %Connect.Error.ValidationError{reason: :invalid_request_timeout}} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"},
               context: context,
               credential_lease: lease,
               request_timeout_ms: 0
             )

    assert {:ok, %{repo: "org/repo"}} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"},
               context: context,
               credential_lease: lease,
               request_timeout_ms: 120_000
             )

    for invalid <- [-1, 120_001, "5_000"] do
      assert {:error, %Connect.Error.ValidationError{reason: :invalid_request_timeout}} =
               Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"},
                 context: context,
                 credential_lease: lease,
                 request_timeout_ms: invalid
               )
    end

    disconnected = %{context | connection: %{context.connection | status: :needs_credentials}}

    assert {:error, %Connect.Error.AuthError{reason: :connection_required}} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"},
               context: disconnected,
               credential_lease: lease
             )

    mismatched_lease = %{lease | connection_id: "other"}

    assert {:error, %Connect.Error.AuthError{reason: :credential_connection_mismatch}} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"},
               context: context,
               credential_lease: mismatched_lease
             )

    assert {:error,
            %Connect.Error.ExecutionError{
              phase: :handler,
              details: %{operation_id: "demo.repo.show", error: "provider_returned_atom"}
            }} =
             RuntimeFixtures.spec(%{action: %{handler: RuntimeFixtures.RawErrorHandler}})
             |> Connect.invoke("demo.repo.show", %{repo: "org/repo"},
               context: context,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.ExecutionError{
              phase: :handler,
              details: %{operation_id: "demo.repo.show", returned: "ok"}
            }} =
             RuntimeFixtures.spec(%{action: %{handler: RuntimeFixtures.InvalidResultHandler}})
             |> Connect.invoke("demo.repo.show", %{repo: "org/repo"},
               context: context,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.ExecutionError{
              phase: :handler,
              details: %{operation_id: "demo.repo.show", message: "handler exploded"}
            }} =
             RuntimeFixtures.spec(%{action: %{handler: RuntimeFixtures.ExplodingHandler}})
             |> Connect.invoke("demo.repo.show", %{repo: "org/repo"},
               context: context,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.ExecutionError{
              phase: :scope_resolver,
              details: %{operation_id: "demo.repo.show", message: "scope resolver exploded"}
            }} =
             RuntimeFixtures.spec(%{
               action: %{scope_resolver: RuntimeFixtures.ExplodingScopeResolver}
             })
             |> Connect.invoke("demo.repo.show", %{repo: "org/repo"},
               context: context,
               credential_lease: lease
             )

    missing_scopes = %{context | connection: %{context.connection | scopes: []}}

    assert {:error, %Connect.Error.AuthError{reason: :missing_scopes, missing_scopes: ["repo"]}} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"},
               context: missing_scopes,
               credential_lease: lease
             )

    reduced_lease = %{lease | scopes: []}

    assert {:error, %Connect.Error.AuthError{reason: :missing_scopes, missing_scopes: ["repo"]}} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"},
               context: context,
               credential_lease: reduced_lease
             )

    expired_lease = %{lease | expires_at: DateTime.add(DateTime.utc_now(), -60, :second)}

    assert {:error, %Connect.Error.AuthError{reason: :credential_lease_expired}} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"},
               context: context,
               credential_lease: expired_lease
             )

    assert {:error, %Connect.Error.AuthError{reason: :credential_lease_expired}} =
             Connect.poll(spec, "demo.repo.changed", %{repo: "org/repo"},
               context: context,
               credential_lease: expired_lease
             )

    unsupported_profile = %{
      context
      | connection: %{context.connection | profile: :installation}
    }

    assert {:error, %Connect.Error.AuthError{reason: :unsupported_auth_profile}} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"},
               context: unsupported_profile,
               credential_lease: lease
             )

    mismatched_binding = %{lease | provider: :other}

    assert {:error,
            %Connect.Error.AuthError{
              reason: :credential_connection_mismatch,
              details: %{field: :provider, expected: :demo, actual: :other}
            }} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "org/repo"},
               context: context,
               credential_lease: mismatched_binding
             )

    assert {:error, %Connect.Error.ValidationError{reason: :signal}} =
             Connect.poll(
               RuntimeFixtures.bad_signal_spec(),
               "demo.repo.changed",
               %{repo: "org/repo"},
               context: context,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.ExecutionError{
              phase: :handler,
              details: %{
                operation_id: "demo.repo.changed",
                expected: :list,
                returned: %{"repo" => "org/repo"}
              }
            }} =
             Connect.poll(
               RuntimeFixtures.non_list_signal_spec(),
               "demo.repo.changed",
               %{repo: "org/repo"},
               context: context,
               credential_lease: lease
             )

    assert {:error,
            %Connect.Error.ExecutionError{
              phase: :handler,
              details: %{
                operation_id: "demo.repo.changed",
                expected: :list,
                returned: nil
              }
            }} =
             Connect.poll(
               RuntimeFixtures.nil_signal_spec(),
               "demo.repo.changed",
               %{repo: "org/repo"},
               context: context,
               credential_lease: lease
             )
  end
end
