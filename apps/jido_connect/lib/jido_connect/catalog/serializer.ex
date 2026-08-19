defmodule Jido.Connect.Catalog.Serializer do
  @moduledoc false

  alias Jido.Connect.{ConnectorCapability, NamedSchema, PolicyRequirement}

  alias Jido.Connect.Catalog.{
    AuthProfileSummary,
    Entry,
    Manifest,
    Pack,
    Tool,
    ToolDescriptor,
    ToolEntry,
    ToolSearchResult
  }

  @spec to_map(
          Entry.t()
          | Manifest.t()
          | Pack.t()
          | ToolEntry.t()
          | ToolSearchResult.t()
          | ToolDescriptor.t()
        ) ::
          map()
  def to_map(%Entry{} = entry) do
    %{
      id: entry.id,
      name: entry.name,
      description: entry.description,
      category: entry.category,
      package: entry.package,
      version: entry.version,
      module: inspect(entry.module),
      status: entry.status,
      tags: entry.tags,
      visibility: entry.visibility,
      docs: entry.docs,
      capabilities: Enum.map(entry.capabilities, &ConnectorCapability.to_map/1),
      policies: Enum.map(entry.policies, &policy_to_map/1),
      schemas: Enum.map(entry.schemas, &schema_to_map/1),
      auth_profiles: Enum.map(entry.auth_profiles, &auth_profile_to_map/1),
      actions: Enum.map(entry.actions, &tool_to_map/1),
      triggers: Enum.map(entry.triggers, &tool_to_map/1),
      metadata: entry.metadata
    }
  end

  def to_map(%Manifest{} = manifest) do
    %{
      id: manifest.id,
      name: manifest.name,
      description: manifest.description,
      app: manifest.app,
      package: manifest.package,
      module: inspect(manifest.module),
      version: manifest.version,
      status: manifest.status,
      category: manifest.category,
      tags: manifest.tags,
      visibility: manifest.visibility,
      docs: manifest.docs,
      capabilities: Enum.map(manifest.capabilities, &ConnectorCapability.to_map/1),
      auth_profiles: Enum.map(manifest.auth_profiles, &auth_profile_to_map/1),
      actions: Enum.map(manifest.actions, &tool_to_map/1),
      triggers: Enum.map(manifest.triggers, &tool_to_map/1),
      generated_modules: generated_modules_to_map(manifest.generated_modules),
      metadata: manifest.metadata
    }
  end

  def to_map(%Pack{} = pack) do
    %{
      id: pack.id,
      label: pack.label,
      description: pack.description,
      filters: json_safe(pack.filters),
      allowed_tools: pack.allowed_tools,
      metadata: json_safe(pack.metadata)
    }
  end

  def to_map(%ToolEntry{} = tool) do
    %{
      provider: tool.provider,
      provider_name: tool.provider_name,
      category: tool.category,
      package: tool.package,
      package_version: tool.package_version,
      integration_module: inspect(tool.integration_module),
      type: tool.type,
      id: tool.id,
      name: tool.name,
      label: tool.label,
      description: tool.description,
      tags: tool.tags,
      module: module_name(tool.module),
      resource: tool.resource,
      verb: tool.verb,
      data_classification: tool.data_classification,
      auth_profile: tool.auth_profile,
      auth_profiles: tool.auth_profiles,
      auth_kinds: tool.auth_kinds,
      policies: tool.policies,
      scopes: tool.scopes,
      risk: tool.risk,
      confirmation: tool.confirmation,
      trigger_kind: tool.trigger_kind,
      source: tool.source
    }
  end

  def to_map(%ToolSearchResult{} = result) do
    %{
      tool: to_map(result.tool),
      score: result.score,
      matched_fields: result.matched_fields,
      metadata: json_safe(result.metadata)
    }
  end

  def to_map(%ToolDescriptor{} = descriptor) do
    %{
      tool: to_map(descriptor.tool),
      provider: json_safe(descriptor.provider),
      input: Enum.map(descriptor.input, &field_to_map/1),
      output: Enum.map(descriptor.output, &field_to_map/1),
      config: Enum.map(descriptor.config, &field_to_map/1),
      signal: Enum.map(descriptor.signal, &field_to_map/1),
      input_json_schema: json_safe(descriptor.input_json_schema),
      output_json_schema: json_safe(descriptor.output_json_schema),
      config_json_schema: json_safe(descriptor.config_json_schema),
      signal_json_schema: json_safe(descriptor.signal_json_schema),
      schema_digest: descriptor.schema_digest,
      strict?: descriptor.strict?,
      auth: Enum.map(descriptor.auth, &auth_profile_to_map/1),
      policies: Enum.map(descriptor.policies, &policy_to_map/1),
      scopes: descriptor.scopes,
      risk: descriptor.risk,
      confirmation: descriptor.confirmation,
      provider_idempotency?: descriptor.provider_idempotency?,
      source: descriptor.source,
      pack: json_safe(descriptor.pack),
      reviewed_fingerprint: descriptor.reviewed_fingerprint,
      metadata: json_safe(descriptor.metadata)
    }
  end

  defp auth_profile_to_map(%AuthProfileSummary{} = auth_profile) do
    %{
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
    }
  end

  defp policy_to_map(%PolicyRequirement{} = policy) do
    %{
      id: policy.id,
      label: policy.label,
      description: policy.description,
      subject: json_safe(policy.subject),
      owner: json_safe(policy.owner),
      decision: policy.decision,
      metadata: json_safe(policy.metadata)
    }
  end

  defp schema_to_map(%NamedSchema{} = schema) do
    %{
      id: schema.id,
      label: schema.label,
      description: schema.description,
      fields: Enum.map(schema.fields, &(Map.from_struct(&1) |> json_safe())),
      metadata: json_safe(schema.metadata)
    }
  end

  defp tool_to_map(%Tool{} = tool) do
    %{
      type: tool.type,
      id: tool.id,
      name: tool.name,
      label: tool.label,
      description: tool.description,
      tags: tool.tags,
      module: module_name(tool.module),
      resource: tool.resource,
      verb: tool.verb,
      data_classification: tool.data_classification,
      auth_profile: tool.auth_profile,
      auth_profiles: tool.auth_profiles,
      policies: tool.policies,
      scopes: tool.scopes,
      risk: tool.risk,
      confirmation: tool.confirmation,
      trigger_kind: tool.trigger_kind,
      source: tool.source
    }
  end

  defp field_to_map(field) do
    field
    |> Map.from_struct()
    |> Map.delete(:__spark_metadata__)
    |> json_safe()
  end

  defp module_name(nil), do: nil
  defp module_name(module), do: inspect(module)

  defp generated_modules_to_map(modules) do
    %{
      actions: Enum.map(Map.get(modules, :actions, []), &module_name/1),
      sensors: Enum.map(Map.get(modules, :sensors, []), &module_name/1),
      plugin: module_name(Map.get(modules, :plugin))
    }
  end

  defp json_safe(tuple) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> Enum.map(&json_safe/1)
  end

  defp json_safe(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {key, json_safe(value)} end)
  end

  defp json_safe(list) when is_list(list), do: Enum.map(list, &json_safe/1)
  defp json_safe(value), do: value
end
