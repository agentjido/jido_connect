defmodule Jido.Connect.Catalog.ToolDescriber do
  @moduledoc false

  alias Jido.Connect.{
    ActionSpec,
    AuthProfile,
    PolicyRequirement,
    Provider,
    Schema,
    Spec,
    TriggerSpec
  }

  alias Jido.Connect.Catalog.{AuthProfileSummary, ToolDescriptor, ToolEntry}
  alias Jido.Connect.Error

  @spec describe(ToolEntry.t()) :: {:ok, ToolDescriptor.t()} | {:error, Error.error()}
  def describe(%ToolEntry{} = tool) do
    with {:ok, %Spec{} = spec} <- Provider.spec(tool.integration_module),
         {:ok, operation} <- find_operation(spec, tool) do
      {:ok, descriptor(spec, tool, operation)}
    end
  end

  defp find_operation(%Spec{} = spec, %ToolEntry{type: :action, id: id}) do
    case Enum.find(spec.actions, &(&1.id == id)) do
      %ActionSpec{} = action -> {:ok, action}
      nil -> {:error, Error.unknown_action(id)}
    end
  end

  defp find_operation(%Spec{} = spec, %ToolEntry{type: :trigger, id: id}) do
    case Enum.find(spec.triggers, &(&1.id == id)) do
      %TriggerSpec{} = trigger -> {:ok, trigger}
      nil -> {:error, Error.unknown_trigger(id)}
    end
  end

  defp descriptor(%Spec{} = spec, %ToolEntry{} = tool, %ActionSpec{} = action) do
    input_json_schema = Schema.to_json_schema(action.input_schema)
    output_json_schema = Schema.to_json_schema(action.output_schema)

    ToolDescriptor.new!(%{
      tool: tool,
      provider: provider_metadata(spec, tool),
      input: action.input,
      output: action.output,
      input_json_schema: input_json_schema,
      output_json_schema: output_json_schema,
      schema_digest: schema_digest(input_json_schema, output_json_schema),
      strict?: strict?(input_json_schema, output_json_schema),
      auth: auth_profiles(spec, action),
      policies: policies(spec, action.policies),
      scopes: action.scopes,
      risk: action.risk,
      confirmation: action.confirmation,
      provider_idempotency?: action.provider_idempotency?,
      source: tool.source,
      metadata: Map.merge(spec.metadata, action.metadata)
    })
  end

  defp descriptor(%Spec{} = spec, %ToolEntry{} = tool, %TriggerSpec{} = trigger) do
    config_json_schema = Schema.to_json_schema(trigger.config_schema)
    signal_json_schema = Schema.to_json_schema(trigger.signal_schema)

    ToolDescriptor.new!(%{
      tool: tool,
      provider: provider_metadata(spec, tool),
      config: trigger.config,
      signal: trigger.signal,
      input_json_schema: config_json_schema,
      output_json_schema: signal_json_schema,
      config_json_schema: config_json_schema,
      signal_json_schema: signal_json_schema,
      schema_digest: schema_digest(config_json_schema, signal_json_schema),
      strict?: strict?(config_json_schema, signal_json_schema),
      auth: auth_profiles(spec, trigger),
      policies: policies(spec, trigger.policies),
      scopes: trigger.scopes,
      risk: tool.risk,
      confirmation: tool.confirmation,
      source: tool.source,
      metadata: Map.merge(spec.metadata, trigger.metadata)
    })
  end

  defp schema_digest(input_json_schema, output_json_schema) do
    Schema.digest(%{
      "input" => input_json_schema,
      "output" => output_json_schema
    })
  end

  defp strict?(input_json_schema, output_json_schema) do
    Schema.strict_object?(input_json_schema) and Schema.strict_object?(output_json_schema)
  end

  defp provider_metadata(%Spec{} = spec, %ToolEntry{} = tool) do
    %{
      id: spec.id,
      name: spec.name,
      description: spec.description,
      category: spec.category,
      package: spec.package || tool.package,
      module: inspect(tool.integration_module),
      status: spec.status || Map.get(spec.metadata, :status),
      tags: spec.tags,
      visibility: spec.visibility,
      docs: spec.docs,
      version: tool.package_version
    }
  end

  defp auth_profiles(%Spec{} = spec, operation) do
    allowed_profiles =
      case operation.auth_profiles do
        [] -> [operation.auth_profile]
        profiles -> profiles
      end

    spec.auth_profiles
    |> Enum.filter(&(&1.id in allowed_profiles))
    |> Enum.map(&auth_summary/1)
  end

  defp auth_summary(%AuthProfile{} = auth_profile) do
    AuthProfileSummary.new!(%{
      id: auth_profile.id,
      kind: auth_profile.kind,
      label: auth_profile.label,
      owner: auth_profile.owner,
      subject: auth_profile.subject,
      setup: auth_profile.setup,
      default?: auth_profile.default?,
      scopes: auth_profile.scopes,
      default_scopes: auth_profile.default_scopes,
      optional_scopes: auth_profile.optional_scopes,
      credential_fields: auth_profile.credential_fields,
      lease_fields: auth_profile.lease_fields
    })
  end

  defp policies(%Spec{} = spec, policy_ids) do
    Enum.filter(spec.policies, fn
      %PolicyRequirement{id: id} -> id in policy_ids
      _other -> false
    end)
  end
end
