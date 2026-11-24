defmodule Jido.Connect.Jido.RuntimeTest do
  use ExUnit.Case, async: true

  alias Jido.Connect

  alias Jido.Connect.Jido.{
    ActionProjection,
    PluginProjection,
    ProjectionBuilder,
    SensorProjection,
    ToolAvailability
  }

  alias Jido.Connect.RuntimeFixtures

  defmodule RaisingConnectionResolver do
    def resolve(_selector), do: raise("tuple resolver exploded")
  end

  defmodule ConnectionResolver do
    def resolve(_selector) do
      {context, _lease} = RuntimeFixtures.context_and_lease()
      context.connection
    end
  end

  defmodule LeaseResolver do
    @behaviour Connect.CredentialResolver

    @impl true
    def resolve_lease(_context, _operation, %{repo: "denied/repo"}) do
      {:error, Connect.Error.auth("sensitive resolver detail", reason: :policy_denied)}
    end

    def resolve_lease(_context, _operation, %{repo: "failure/repo"}) do
      raise "sensitive resolver detail"
    end

    def resolve_lease(context, operation, input) do
      send(context.metadata.test_pid, {:resolved, operation, input})

      Connect.CredentialLease.from_connection(context.connection, %{},
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
      )
    end
  end

  defmodule CaptureOptionsHandler do
    def run(input, %{context: %{metadata: %{test_pid: test_pid}}} = runtime) do
      send(test_pid, {:runtime_controls, runtime.provider_client, runtime.request_timeout_ms})
      {:ok, input}
    end
  end

  defmodule CaptureOptionsIntegration do
    def integration do
      Jido.Connect.RuntimeFixtures.spec(%{
        action: %{handler: Jido.Connect.Jido.RuntimeTest.CaptureOptionsHandler}
      })
    end
  end

  test "generated actions forward trusted provider client and timeout controls" do
    spec = CaptureOptionsIntegration.integration()
    projection = ProjectionBuilder.build(CaptureOptionsIntegration, spec)
    {context, lease} = RuntimeFixtures.context_and_lease()
    context = %{context | metadata: %{test_pid: self()}}

    assert {:ok, %{repo: "org/repo"}} =
             Connect.JidoActionRuntime.run(hd(projection.actions), %{repo: "org/repo"}, %{
               integration_context: context,
               credential_lease: lease,
               provider_client: CaptureOptionsHandler,
               request_timeout_ms: 5_432
             })

    assert_received {:runtime_controls, CaptureOptionsHandler, 5_432}
  end

  test "actions resolve a lease after validating input and authorizing the connection" do
    projection = RuntimeFixtures.action_projection()
    {context, lease} = RuntimeFixtures.context_and_lease()
    context = %{context | metadata: %{test_pid: self()}}
    opts = %{integration_context: context, credential_resolver: LeaseResolver}

    assert {:ok, %{repo: "org/repo"}} =
             Connect.JidoActionRuntime.run(projection, %{repo: "org/repo"}, opts)

    assert_received {:resolved, "demo.repo.show", %{repo: "org/repo"}}

    assert {:error, %Connect.Error.ValidationError{}} =
             Connect.JidoActionRuntime.run(projection, %{repo: 42}, opts)

    assert {:error, %Connect.Error.AuthError{reason: :connection_required}} =
             Connect.JidoActionRuntime.run(projection, %{repo: "org/repo"}, %{
               opts
               | integration_context: %{context | tenant_id: "other_tenant"}
             })

    assert {:error, %Connect.Error.AuthError{reason: :policy_denied}} =
             Connect.JidoActionRuntime.run(
               projection,
               %{repo: "org/repo"},
               Map.put(opts, :policy, fn _, _, _, _ -> :deny end)
             )

    refute_received {:resolved, _, _}

    assert {:error, %Connect.Error.AuthError{reason: :policy_denied, message: message}} =
             Connect.JidoActionRuntime.run(
               projection,
               %{repo: "denied/repo"},
               Map.put(opts, :credential_lease, lease)
             )

    assert message == "Credential resolution denied"

    assert {:error,
            %Connect.Error.ExecutionError{
              phase: :credential_resolution,
              details: %{operation_id: "demo.repo.show"},
              message: "Credential resolver failed"
            }} = Connect.JidoActionRuntime.run(projection, %{repo: "failure/repo"}, opts)
  end

  test "poll sensors resolve a fresh lease on each tick" do
    sensor = RuntimeFixtures.sensor_projection()
    {context, _lease} = RuntimeFixtures.context_and_lease()
    context = %{context | metadata: %{test_pid: self()}}
    opts = %{integration_context: context, credential_resolver: LeaseResolver}

    assert {:ok, state, [{:schedule, 1_000}]} =
             Connect.JidoSensorRuntime.init(sensor, %{repo: "org/repo"}, opts)

    refute_received {:resolved, _, _}

    assert {:ok, state, [{:emit, _signal}, {:schedule, 1_000}]} =
             Connect.JidoSensorRuntime.handle_event(sensor, :tick, state)

    assert_received {:resolved, "demo.repo.changed", %{repo: "org/repo"}}
    refute Map.has_key?(state.context, :credential_lease)

    assert {:ok, _state, [{:emit, _signal}, {:schedule, 1_000}]} =
             Connect.JidoSensorRuntime.handle_event(sensor, :tick, state)

    assert_received {:resolved, "demo.repo.changed", %{repo: "org/repo"}}
  end

  test "direct invocation and polling use the context resolver and honor explicit options" do
    spec = RuntimeFixtures.spec()
    {context, lease} = RuntimeFixtures.context_and_lease()
    context = %{context | credential_resolver: LeaseResolver, metadata: %{test_pid: self()}}
    input = %{repo: "org/repo"}

    assert {:ok, ^input} = Connect.invoke(spec, "demo.repo.show", input, context: context)
    assert_received {:resolved, "demo.repo.show", ^input}

    assert {:ok, %{signals: [^input], checkpoint: "next"}} =
             Connect.poll(spec, "demo.repo.changed", input, context: context)

    assert_received {:resolved, "demo.repo.changed", ^input}

    assert {:error, %Connect.Error.AuthError{reason: :policy_denied}} =
             Connect.invoke(spec, "demo.repo.show", %{repo: "denied/repo"},
               context: context,
               credential_lease: lease
             )

    assert {:error, %Connect.Error.ConfigError{key: :credential_resolver}} =
             Connect.invoke(spec, "demo.repo.show", input,
               context: context,
               credential_resolver: nil
             )

    refute_received {:resolved, _, _}
  end

  test "a bare sensor context resolves its selector at each tick and keeps the checkpoint" do
    sensor = %{
      RuntimeFixtures.sensor_projection()
      | integration_module: RuntimeFixtures.AdvancingIntegration
    }

    {resolved, _lease} = RuntimeFixtures.context_and_lease()
    {:ok, selector} = Connect.ConnectionSelector.explicit(:demo, resolved.connection.id)

    context = %{
      resolved
      | connection: nil,
        connection_selector: selector,
        connection_resolver: {ConnectionResolver, :resolve},
        credential_resolver: LeaseResolver,
        metadata: %{test_pid: self()}
    }

    input = %{repo: "org/repo"}

    assert {:ok, state, [{:schedule, 1_000}]} =
             Connect.JidoSensorRuntime.init(sensor, input, context)

    assert {:ok, state, [{:emit, first_signal}, {:schedule, 1_000}]} =
             Connect.JidoSensorRuntime.handle_event(sensor, :tick, state)

    assert first_signal.data.repo == "org/repo:first"
    assert_received {:resolved, "demo.repo.changed", ^input}

    fresh_context = %{context | claims: %{refreshed: true}}
    state = Connect.Sensor.replace_context(state, fresh_context)
    assert state.context == fresh_context
    assert state.checkpoint == "first"

    assert {:ok, state, [{:emit, second_signal}, {:schedule, 1_000}]} =
             Connect.JidoSensorRuntime.handle_event(sensor, :tick, state)

    assert second_signal.data.repo == "org/repo:second"
    assert_received {:resolved, "demo.repo.changed", ^input}

    override = %{
      integration_context: fresh_context,
      connection_resolver: fn _selector -> %{resolved.connection | id: "other"} end
    }

    assert {:error, %Connect.Error.AuthError{reason: :connection_required}} =
             Connect.JidoSensorRuntime.handle_event(
               sensor,
               :tick,
               Connect.Sensor.replace_context(state, override)
             )

    refute_received {:resolved, _, _}
  end

  test "generated availability keeps host policy requirements" do
    spec =
      RuntimeFixtures.spec(%{
        action: %{host_policy_required?: true},
        trigger: %{host_policy_required?: true}
      })

    projection = ProjectionBuilder.build(RuntimeFixtures.Integration, spec)
    {context, _lease} = RuntimeFixtures.context_and_lease()

    for operation <- spec.actions ++ spec.triggers do
      assert :disabled_by_policy =
               Connect.Authorization.connection_availability(operation, context.connection)
    end

    assert Enum.map(projection.actions ++ projection.sensors, & &1.host_policy_required?) ==
             [true, true]

    assert [
             %ToolAvailability{state: :disabled_by_policy},
             %ToolAvailability{state: :disabled_by_policy}
           ] =
             Connect.JidoPluginRuntime.tool_availability(projection, %{
               connection: context.connection
             })

    allow_policy = fn _operation, _input, _context, _connection -> :ok end

    assert [%ToolAvailability{state: :available}, %ToolAvailability{state: :available}] =
             Connect.JidoPluginRuntime.tool_availability(projection, %{
               connection: context.connection,
               context: context,
               policy: allow_policy
             })
  end

  test "Jido runtimes adapt projections without provider logic" do
    {context, lease} = RuntimeFixtures.context_and_lease()
    projection = RuntimeFixtures.action_projection()

    assert {:ok, %{repo: "org/repo"}} =
             Connect.JidoActionRuntime.run(projection, %{repo: "org/repo"}, %{
               integration_context: context,
               credential_lease: lease
             })

    assert {:ok, %{repo: "org/repo"}} =
             Connect.JidoActionRuntime.run(projection, %{repo: "org/repo"}, %{
               context: context,
               credential_lease: lease
             })

    assert {:ok, %{repo: "org/repo"}} =
             Connect.JidoActionRuntime.run(projection, %{repo: "org/repo"}, %{
               tenant_id: context.tenant_id,
               actor: context.actor,
               connection: context.connection,
               credential_lease: lease
             })

    selector =
      Connect.ConnectionSelector.per_actor(:demo, "tenant_1", "user_1",
        profile: :user,
        required_scopes: ["repo"]
      )
      |> elem(1)

    tenant_context = %{context | connection: nil, connection_selector: selector}

    assert {:ok, %{repo: "org/repo"}} =
             Connect.JidoActionRuntime.run(projection, %{repo: "org/repo"}, %{
               integration_context: tenant_context,
               connection_resolver: fn ^selector, ^projection, _agent_context ->
                 context.connection
               end,
               credential_lease: lease
             })

    mismatched_selector =
      Connect.ConnectionSelector.tenant_default(:demo, "tenant_1", profile: :user)
      |> elem(1)

    mismatched_context = %{context | connection: nil, connection_selector: mismatched_selector}

    assert {:error, %Connect.Error.AuthError{reason: :connection_required}} =
             Connect.JidoActionRuntime.run(projection, %{repo: "org/repo"}, %{
               integration_context: mismatched_context,
               connection_resolver: fn ^mismatched_selector, ^projection, _agent_context ->
                 context.connection
               end,
               credential_lease: lease
             })

    assert {:error,
            %Connect.Error.ExecutionError{
              phase: :connection_resolver,
              details: %{message: "Jido Connect callback raised"}
            }} =
             Connect.JidoActionRuntime.run(projection, %{repo: "org/repo"}, %{
               integration_context: tenant_context,
               connection_resolver: fn ^selector, ^projection, _agent_context ->
                 raise "resolver exploded"
               end,
               credential_lease: lease
             })

    assert {:error, %Connect.Error.AuthError{reason: :context_required}} =
             Connect.JidoActionRuntime.run(projection, %{repo: "org/repo"}, %{
               credential_lease: lease
             })

    assert {:error, %Connect.Error.AuthError{reason: :credential_lease_required}} =
             Connect.JidoActionRuntime.run(projection, %{repo: "org/repo"}, %{
               integration_context: context
             })

    assert {:error, %Connect.Error.AuthError{reason: :credential_lease_required}} =
             Connect.JidoActionRuntime.run(projection, %{repo: "org/repo"}, context)

    raising_projection = %{projection | integration_module: RuntimeFixtures.RaisingIntegration}

    assert {:error,
            %Connect.Error.ExecutionError{
              phase: :provider_integration,
              details: %{message: "Jido Connect callback raised"}
            }} =
             Connect.JidoActionRuntime.run(raising_projection, %{repo: "org/repo"}, %{
               integration_context: context,
               credential_lease: lease
             })

    sensor = RuntimeFixtures.sensor_projection()

    assert {:ok, state, [{:schedule, 1_000}]} =
             Connect.JidoSensorRuntime.init(sensor, %{repo: "org/repo"}, %{
               integration_context: context,
               credential_lease: lease
             })

    assert {:ok, state, [{:emit, signal}, {:schedule, 1_000}]} =
             Connect.JidoSensorRuntime.handle_event(sensor, :tick, state)

    assert signal.type == "demo.repo.changed"
    assert signal.source == "/jido/connect/demo"
    assert signal.data.repo == "org/repo"
    assert state.checkpoint == "next"

    advancing_sensor = %{sensor | integration_module: RuntimeFixtures.AdvancingIntegration}

    assert {:ok, advancing_state, [{:schedule, 1_000}]} =
             Connect.JidoSensorRuntime.init(advancing_sensor, %{repo: "org/repo"}, %{
               integration_context: context,
               credential_lease: lease
             })

    assert {:ok, advancing_state, [{:emit, first_signal}, {:schedule, 1_000}]} =
             Connect.JidoSensorRuntime.handle_event(advancing_sensor, :tick, advancing_state)

    assert first_signal.data.repo == "org/repo:first"
    assert advancing_state.checkpoint == "first"

    fresh_lease = %{lease | expires_at: DateTime.add(DateTime.utc_now(), 300, :second)}

    advancing_state =
      Connect.Sensor.replace_context(advancing_state, %{
        integration_context: context,
        credential_lease: fresh_lease
      })

    assert advancing_state.checkpoint == "first"
    assert advancing_state.context.credential_lease == fresh_lease

    assert {:ok, advancing_state, [{:emit, second_signal}, {:schedule, 1_000}]} =
             Connect.JidoSensorRuntime.handle_event(advancing_sensor, :tick, advancing_state)

    assert second_signal.data.repo == "org/repo:second"
    assert advancing_state.checkpoint == "second"

    assert {:ok, selector_state, [{:schedule, 1_000}]} =
             Connect.JidoSensorRuntime.init(sensor, %{repo: "org/repo"}, %{
               integration_context: tenant_context,
               connection_resolver: fn ^selector, ^sensor, _runtime_context ->
                 context.connection
               end,
               credential_lease: lease
             })

    assert {:ok, _state, [{:emit, _selector_signal}, {:schedule, 1_000}]} =
             Connect.JidoSensorRuntime.handle_event(sensor, :tick, selector_state)

    raising_sensor = %{sensor | integration_module: RuntimeFixtures.RaisingIntegration}

    assert {:ok, raising_state, [{:schedule, 1_000}]} =
             Connect.JidoSensorRuntime.init(raising_sensor, %{repo: "org/repo"}, %{
               integration_context: context,
               credential_lease: lease
             })

    assert {:error,
            %Connect.Error.ExecutionError{
              phase: :provider_integration,
              details: %{message: "Jido Connect callback raised"}
            }} =
             Connect.JidoSensorRuntime.handle_event(raising_sensor, :tick, raising_state)

    webhook = %{sensor | kind: :webhook, runtime_mode: :metadata_only}
    assert {:ok, %{projection: ^webhook}} = Connect.JidoSensorRuntime.init(webhook, %{}, %{})

    assert {:error,
            %Connect.Error.ExecutionError{
              phase: :webhook_runtime,
              details: %{
                trigger_id: "demo.repo.changed",
                runtime_mode: :metadata_only,
                event_type: :atom
              }
            }} = Connect.JidoSensorRuntime.handle_event(webhook, :anything, :state)

    secret_event = %{access_token: "REVIEW_SENTINEL", payload: %{value: 1}}

    assert {:error, %Connect.Error.ExecutionError{details: details} = error} =
             Connect.JidoSensorRuntime.handle_event(webhook, secret_event, :state)

    assert details.event_type == :map
    refute Map.has_key?(details, :event)
    refute inspect(error) =~ "REVIEW_SENTINEL"
  end

  test "plugin runtime filters subscriptions and availability" do
    {context, _lease} = RuntimeFixtures.context_and_lease()
    projection = RuntimeFixtures.plugin_projection()

    assert [action] = Connect.JidoPluginRuntime.filtered_actions(projection, %{})
    assert action.action_id == "demo.repo.show"

    assert [] = Connect.JidoPluginRuntime.filtered_actions(projection, %{allowed_actions: []})

    assert [sensor] = Connect.JidoPluginRuntime.filtered_sensors(projection, %{})
    assert sensor.trigger_id == "demo.repo.changed"

    assert [{RuntimeFixtures.Integration.Sensors.RepoChanged, %{repo: "org/repo"}}] =
             Connect.JidoPluginRuntime.subscriptions(
               projection,
               %{trigger_config: %{repo: "org/repo"}},
               %{}
             )

    second_sensor = %{
      sensor
      | module: RuntimeFixtures.Integration.Sensors.SecondRepoChanged,
        trigger_id: "demo.repo.second_changed",
        name: "demo_repo_second_changed"
    }

    multi_sensor_projection = %{projection | sensors: [sensor, second_sensor]}

    assert [
             {RuntimeFixtures.Integration.Sensors.RepoChanged, %{repo: "org/one"}},
             {RuntimeFixtures.Integration.Sensors.SecondRepoChanged, %{repo: "org/two"}}
           ] =
             Connect.JidoPluginRuntime.subscriptions(
               multi_sensor_projection,
               %{
                 trigger_configs: %{
                   "demo.repo.changed" => %{repo: "org/one"},
                   "demo.repo.second_changed" => %{repo: "org/two"}
                 },
                 trigger_config: %{repo: "fallback/repo"}
               },
               %{}
             )

    assert [
             %ToolAvailability{state: :available, connection_id: "conn_1"},
             %ToolAvailability{state: :available, connection_id: "conn_1"}
           ] =
             Connect.JidoPluginRuntime.tool_availability(projection, %{
               connection: context.connection
             })

    deny_policy = fn _operation, _input, _context, _connection -> {:deny, :hidden_by_host} end

    assert [
             %ToolAvailability{state: :disabled_by_policy, connection_id: "conn_1"},
             %ToolAvailability{state: :disabled_by_policy, connection_id: "conn_1"}
           ] =
             Connect.JidoPluginRuntime.tool_availability(projection, %{
               connection: context.connection,
               context: context,
               policy: deny_policy
             })

    assert [
             %ToolAvailability{state: :connection_required, connection_id: "conn_1"},
             %ToolAvailability{state: :connection_required, connection_id: "conn_1"}
           ] =
             Connect.JidoPluginRuntime.tool_availability(projection, %{
               connection_id: "conn_1"
             })

    assert [
             %ToolAvailability{state: :available, connection_id: "conn_1"},
             %ToolAvailability{state: :available, connection_id: "conn_1"}
           ] =
             Connect.JidoPluginRuntime.tool_availability(projection, %{
               connection_id: "conn_1",
               connection_resolver: fn "conn_1" -> context.connection end
             })

    assert [
             %ToolAvailability{state: :missing_scopes, connection_id: "conn_1"},
             %ToolAvailability{state: :missing_scopes, connection_id: "conn_1"}
           ] =
             Connect.JidoPluginRuntime.tool_availability(projection, %{
               connection_id: "conn_1",
               connection_resolver: fn _connection_id ->
                 %{context.connection | scopes: []}
               end
             })

    tenant_selector =
      Connect.ConnectionSelector.per_actor(:demo, "tenant_1", "user_1", profile: :user)
      |> elem(1)

    assert [
             %ToolAvailability{
               state: :connection_required,
               connection_selector: ^tenant_selector
             },
             %ToolAvailability{
               state: :connection_required,
               connection_selector: ^tenant_selector
             }
           ] =
             Connect.JidoPluginRuntime.tool_availability(projection, %{
               connection_selector: tenant_selector
             })

    assert [
             %ToolAvailability{state: :available, connection_id: "conn_1"},
             %ToolAvailability{state: :available, connection_id: "conn_1"}
           ] =
             Connect.JidoPluginRuntime.tool_availability(projection, %{
               connection_selector: tenant_selector,
               connection_resolver: fn ^tenant_selector, _operation, _config ->
                 context.connection
               end
             })

    mismatched_selector =
      Connect.ConnectionSelector.tenant_default(:demo, "tenant_1", profile: :user)
      |> elem(1)

    assert [
             %ToolAvailability{
               state: :connection_required,
               connection_selector: ^mismatched_selector
             },
             %ToolAvailability{
               state: :connection_required,
               connection_selector: ^mismatched_selector
             }
           ] =
             Connect.JidoPluginRuntime.tool_availability(projection, %{
               connection_selector: mismatched_selector,
               connection_resolver: fn ^mismatched_selector, _operation, _config ->
                 context.connection
               end
             })

    assert [
             %ToolAvailability{
               state: :connection_required,
               connection_selector: {:provider, :demo}
             },
             %ToolAvailability{
               state: :connection_required,
               connection_selector: {:provider, :demo}
             }
           ] =
             Connect.JidoPluginRuntime.tool_availability(projection, %{
               connection_selector: {:provider, :demo}
             })

    assert {:error,
            %Connect.Error.ExecutionError{
              phase: :connection_resolver,
              details: %{message: "Jido Connect callback raised"}
            }} =
             Connect.ConnectionSelector.resolve("conn_1", {RaisingConnectionResolver, :resolve})

    assert [
             %ToolAvailability{
               state: :configuration_error,
               connection_id: "conn_1",
               metadata: %{error: %{type: :execution_error}}
             },
             %ToolAvailability{
               state: :configuration_error,
               connection_id: "conn_1",
               metadata: %{error: %{type: :execution_error}}
             }
           ] =
             Connect.JidoPluginRuntime.tool_availability(projection, %{
               connection_id: "conn_1",
               connection_resolver: {RaisingConnectionResolver, :resolve}
             })

    broken_action = %{
      RuntimeFixtures.action_projection()
      | scope_resolver: RuntimeFixtures.ExplodingScopeResolver
    }

    broken_projection = %{projection | actions: [broken_action], sensors: []}

    assert [
             %ToolAvailability{
               state: :configuration_error,
               connection_id: "conn_1",
               metadata: %{error: %{type: :execution_error}}
             }
           ] =
             Connect.JidoPluginRuntime.tool_availability(broken_projection, %{
               connection: context.connection
             })
  end

  test "projection structs expose Zoi schemas and safe constructors" do
    action = RuntimeFixtures.action_projection()
    sensor = RuntimeFixtures.sensor_projection()
    plugin = RuntimeFixtures.plugin_projection()

    assert ActionProjection.schema()
    assert SensorProjection.schema()
    assert PluginProjection.schema()
    assert ToolAvailability.schema()

    assert {:ok, ^action} = ActionProjection.new(Map.from_struct(action))
    assert {:ok, ^sensor} = SensorProjection.new(Map.from_struct(sensor))
    assert {:ok, ^plugin} = PluginProjection.new(Map.from_struct(plugin))

    availability = ToolAvailability.new!(%{tool: "demo.repo.show", state: :available})
    assert {:ok, ^availability} = ToolAvailability.new(Map.from_struct(availability))
  end
end
