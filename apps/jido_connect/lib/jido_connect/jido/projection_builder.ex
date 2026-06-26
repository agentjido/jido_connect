defmodule Jido.Connect.Jido.ProjectionBuilder do
  @moduledoc false

  alias Jido.Connect.Jido.{ActionProjection, PluginProjection, SensorProjection}
  alias Jido.Connect.Spec

  def build(integration_module, %Spec{} = spec) do
    action_projections =
      Enum.map(spec.actions, fn action ->
        ActionProjection.new!(%{
          module: Module.concat([integration_module, Actions, Macro.camelize("#{action.name}")]),
          integration_module: integration_module,
          integration_id: spec.id,
          action_id: action.id,
          name: jido_name(action.id),
          label: action.label,
          description: action.description || action.label,
          tags: action.tags,
          resource: action.resource,
          verb: action.verb,
          data_classification: action.data_classification,
          input: action.input,
          output: action.output,
          input_schema: action.input_schema,
          output_schema: action.output_schema,
          auth_profile: action.auth_profile,
          auth_profiles: action.auth_profiles,
          policies: action.policies,
          scopes: action.scopes,
          scope_resolver: action.scope_resolver,
          risk: action.risk,
          confirmation: action.confirmation
        })
      end)

    sensor_projections =
      Enum.map(spec.triggers, fn trigger ->
        SensorProjection.new!(%{
          module: Module.concat([integration_module, Sensors, Macro.camelize("#{trigger.name}")]),
          integration_module: integration_module,
          integration_id: spec.id,
          trigger_id: trigger.id,
          name: jido_name(trigger.id),
          label: trigger.label,
          description: trigger.description || trigger.label,
          tags: trigger.tags,
          resource: trigger.resource,
          verb: trigger.verb,
          data_classification: trigger.data_classification,
          kind: trigger.kind,
          runtime_mode: sensor_runtime_mode(trigger.kind),
          config: trigger.config,
          signal: trigger.signal,
          config_schema: trigger.config_schema,
          signal_schema: trigger.signal_schema,
          signal_type: trigger.id,
          signal_source: "/jido/connect/#{spec.id}",
          auth_profile: trigger.auth_profile,
          auth_profiles: trigger.auth_profiles,
          policies: trigger.policies,
          scopes: trigger.scopes,
          scope_resolver: trigger.scope_resolver,
          interval_ms: trigger.interval_ms
        })
      end)

    PluginProjection.new!(%{
      module: Module.concat([integration_module, Plugin]),
      integration_module: integration_module,
      integration_id: spec.id,
      name: jido_name("#{spec.id}"),
      description: "#{spec.name} integration tools.",
      actions: action_projections,
      sensors: sensor_projections
    })
  end

  defp jido_name(value) do
    value
    |> to_string()
    |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
  end

  defp sensor_runtime_mode(:poll), do: :poll
  defp sensor_runtime_mode(:webhook), do: :metadata_only
end
