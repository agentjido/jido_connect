defmodule Jido.Connect.Jido.RuntimeTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Jido.{ActionProjection, PluginProjection, SensorProjection, ToolAvailability}
  alias Jido.Connect.RuntimeFixtures

  defmodule RaisingConnectionResolver do
    def resolve(_selector), do: raise("tuple resolver exploded")
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
