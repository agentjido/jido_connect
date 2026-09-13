defmodule Jido.Connect.Jido.ModuleGenerator do
  @moduledoc false

  alias Jido.Connect.Jido.{ActionProjection, PluginProjection, SensorProjection}

  def generated_modules_ast(%PluginProjection{} = projection) do
    action_modules = Enum.map(projection.actions, &action_module_ast/1)
    sensor_modules = Enum.map(projection.sensors, &sensor_module_ast/1)
    plugin_module = plugin_module_ast(projection)

    action_modules ++ sensor_modules ++ [plugin_module]
  end

  defp action_module_ast(%ActionProjection{} = projection) do
    quote do
      defmodule unquote(projection.module) do
        @moduledoc false

        use Jido.Action,
          name: unquote(projection.name),
          description: unquote(projection.description),
          schema: unquote(Macro.escape(projection.input_schema)),
          output_schema: unquote(Macro.escape(projection.output_schema))

        @projection unquote(Macro.escape(projection))

        def jido_connect_projection, do: @projection
        def operation_id, do: @projection.action_id

        @impl Jido.Action
        def run(params, context) do
          Jido.Connect.JidoActionRuntime.run(@projection, params, context)
        end
      end
    end
  end

  defp sensor_module_ast(%SensorProjection{} = projection) do
    quote do
      defmodule unquote(projection.module) do
        @moduledoc false

        use Jido.Sensor,
          name: unquote(projection.name),
          description: unquote(projection.description),
          schema: unquote(Macro.escape(projection.config_schema))

        @projection unquote(Macro.escape(projection))

        def jido_connect_projection, do: @projection
        def trigger_id, do: @projection.trigger_id
        def signal_type, do: @projection.signal_type
        def signal_source, do: @projection.signal_source
        def runtime_mode, do: @projection.runtime_mode

        @impl Jido.Sensor
        def init(config, context) do
          Jido.Connect.JidoSensorRuntime.init(@projection, config, context)
        end

        @impl Jido.Sensor
        def handle_event(event, state) do
          Jido.Connect.JidoSensorRuntime.handle_event(@projection, event, state)
        end
      end
    end
  end

  defp plugin_module_ast(%PluginProjection{} = projection) do
    action_modules = Enum.map(projection.actions, & &1.module)

    quote do
      defmodule unquote(projection.module) do
        @moduledoc false

        use Jido.Plugin,
          name: unquote(projection.name),
          state_key: unquote(projection.integration_id),
          description: unquote(projection.description),
          actions: unquote(Macro.escape(action_modules)),
          config_schema: Zoi.map()

        @projection unquote(Macro.escape(projection))

        def jido_connect_projection, do: @projection
        defoverridable plugin_spec: 1

        @impl Jido.Plugin
        def plugin_spec(config) do
          %Jido.Plugin.Spec{
            module: __MODULE__,
            name: name(),
            state_key: state_key(),
            description: description(),
            category: category(),
            vsn: vsn(),
            schema: schema(),
            config_schema: config_schema(),
            config: config,
            signal_patterns: signal_patterns(),
            tags: tags(),
            actions:
              @projection
              |> Jido.Connect.JidoPluginRuntime.filtered_actions(config)
              |> Enum.map(& &1.module)
          }
        end

        @impl Jido.Plugin
        def subscriptions(config, context) do
          Jido.Connect.JidoPluginRuntime.subscriptions(@projection, config, context)
        end

        def tool_availability(config \\ %{}) do
          Jido.Connect.JidoPluginRuntime.tool_availability(@projection, config)
        end
      end
    end
  end
end
