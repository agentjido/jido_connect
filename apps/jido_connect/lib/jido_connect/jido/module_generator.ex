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

        @behaviour Jido.Connect.Sensor

        def name, do: unquote(projection.name)
        def description, do: unquote(projection.description)
        def schema, do: unquote(Macro.escape(projection.config_schema))

        @projection unquote(Macro.escape(projection))

        def jido_connect_projection, do: @projection
        def trigger_id, do: @projection.trigger_id
        def signal_type, do: @projection.signal_type
        def signal_source, do: @projection.signal_source
        def runtime_mode, do: @projection.runtime_mode

        @impl Jido.Connect.Sensor
        def init(config, context) do
          Jido.Connect.JidoSensorRuntime.init(@projection, config, context)
        end

        @impl Jido.Connect.Sensor
        def handle_event(event, state) do
          Jido.Connect.JidoSensorRuntime.handle_event(@projection, event, state)
        end
      end
    end
  end

  defp plugin_module_ast(%PluginProjection{} = projection) do
    quote do
      defmodule unquote(projection.module) do
        @moduledoc false

        @projection unquote(Macro.escape(projection))

        def name, do: @projection.name
        def description, do: @projection.description
        def jido_connect_projection, do: @projection

        # Connect discovery data. This is not a Jido.Plugin.Spec.
        def plugin_spec(config \\ %{}) do
          %{
            module: __MODULE__,
            name: name(),
            actions: __MODULE__.actions(config)
          }
        end

        def actions(config \\ %{}) do
          @projection
          |> Jido.Connect.JidoPluginRuntime.filtered_actions(config)
          |> Enum.map(& &1.module)
        end

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
