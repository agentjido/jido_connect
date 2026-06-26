defmodule Jido.Connect.Catalog.Builder do
  @moduledoc false

  alias Jido.Connect.{
    ActionSpec,
    AuthProfile,
    ConnectorCapability,
    TriggerSpec
  }

  alias Jido.Connect.Catalog.{AuthProfileSummary, Entry, Manifest, Tool, ToolEntry}

  @spec entry(module(), keyword()) :: Entry.t()
  def entry(integration_module, opts \\ []) when is_atom(integration_module) do
    spec = integration_module.integration()
    projection = projection(integration_module)

    entry_from_spec(spec, integration_module, projection, opts)
  end

  @spec entry_from_spec(Jido.Connect.Spec.t(), module(), term(), keyword()) :: Entry.t()
  def entry_from_spec(spec, integration_module, projection, opts \\ []) do
    Entry.new!(%{
      id: spec.id,
      name: spec.name,
      description: spec.description,
      category: spec.category,
      package: spec.package || Map.get(spec.metadata, :package),
      version:
        Keyword.get(opts, :version) || metadata_value(spec.metadata, :version) ||
          package_version(spec.package || Map.get(spec.metadata, :package)),
      module: integration_module,
      status:
        Keyword.get(opts, :status, spec.status || Map.get(spec.metadata, :status, :available)),
      tags: spec.tags,
      visibility: spec.visibility,
      docs: spec.docs,
      capabilities: ConnectorCapability.from_spec(spec, integration_module),
      policies: spec.policies,
      schemas: spec.schemas,
      auth_profiles: Enum.map(spec.auth_profiles, &auth_summary/1),
      actions: Enum.map(spec.actions, &action_tool(&1, projection)),
      triggers: Enum.map(spec.triggers, &trigger_tool(&1, projection)),
      metadata: spec.metadata
    })
  end

  @spec manifest(module(), keyword()) :: Manifest.t()
  def manifest(integration_module, opts \\ []) when is_atom(integration_module) do
    spec = integration_module.integration()
    projection = projection(integration_module)

    manifest_from_spec(spec, integration_module, projection, opts)
  end

  @spec manifest_from_spec(Jido.Connect.Spec.t(), module(), term(), keyword()) :: Manifest.t()
  def manifest_from_spec(spec, integration_module, projection, opts \\ []) do
    Entry.new!(%{
      id: spec.id,
      name: spec.name,
      description: spec.description,
      category: spec.category,
      package: spec.package || Map.get(spec.metadata, :package),
      version:
        Keyword.get(opts, :version) || metadata_value(spec.metadata, :version) ||
          package_version(spec.package || Map.get(spec.metadata, :package)),
      module: integration_module,
      status:
        Keyword.get(opts, :status, spec.status || Map.get(spec.metadata, :status, :available)),
      tags: spec.tags,
      visibility: spec.visibility,
      docs: spec.docs,
      capabilities: ConnectorCapability.from_spec(spec, integration_module),
      policies: spec.policies,
      schemas: spec.schemas,
      auth_profiles: Enum.map(spec.auth_profiles, &auth_summary/1),
      actions: Enum.map(spec.actions, &action_tool(&1, projection)),
      triggers: Enum.map(spec.triggers, &trigger_tool(&1, projection)),
      metadata: spec.metadata
    })
    |> manifest_from_entry(projection)
  end

  defp manifest_from_entry(%Entry{} = entry, projection) do
    Manifest.new!(%{
      id: entry.id,
      name: entry.name,
      description: entry.description,
      app: entry.package,
      package: entry.package,
      module: entry.module,
      version:
        entry.version || metadata_value(entry.metadata, :version) ||
          package_version(entry.package),
      status: entry.status,
      category: entry.category,
      tags: entry.tags,
      visibility: entry.visibility,
      docs: entry.docs,
      capabilities: entry.capabilities,
      auth_profiles: entry.auth_profiles,
      actions: entry.actions,
      triggers: entry.triggers,
      generated_modules: generated_modules(projection),
      metadata: entry.metadata
    })
  end

  @spec tool_entries(Entry.t()) :: [ToolEntry.t()]
  def tool_entries(%Entry{} = entry) do
    Enum.map(entry.actions ++ entry.triggers, &tool_entry(entry, &1))
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

  defp action_tool(%ActionSpec{} = action, projection) do
    Tool.new!(%{
      type: :action,
      id: action.id,
      name: action.name,
      label: action.label,
      description: action.description,
      tags: action.tags,
      module: projection_module(projection, :actions, action.id),
      resource: action.resource,
      verb: action.verb,
      data_classification: action.data_classification,
      auth_profile: action.auth_profile,
      auth_profiles: operation_auth_profiles(action),
      policies: action.policies,
      scopes: action.scopes,
      risk: action.risk,
      confirmation: action.confirmation
    })
  end

  defp trigger_tool(%TriggerSpec{} = trigger, projection) do
    Tool.new!(%{
      type: :trigger,
      id: trigger.id,
      name: trigger.name,
      label: trigger.label,
      description: trigger.description,
      tags: trigger.tags,
      module: projection_module(projection, :sensors, trigger.id),
      resource: trigger.resource,
      verb: trigger.verb,
      data_classification: trigger.data_classification,
      auth_profile: trigger.auth_profile,
      auth_profiles: operation_auth_profiles(trigger),
      policies: trigger.policies,
      scopes: trigger.scopes,
      trigger_kind: trigger.kind
    })
  end

  defp operation_auth_profiles(%{auth_profiles: []} = operation), do: [operation.auth_profile]
  defp operation_auth_profiles(%{auth_profiles: profiles}), do: profiles

  defp projection(integration_module) do
    if function_exported?(integration_module, :jido_projection, 0) do
      integration_module.jido_projection()
    end
  end

  defp generated_modules(nil), do: %{actions: [], sensors: [], plugin: nil}

  defp generated_modules(projection) do
    %{
      actions: Enum.map(projection.actions, & &1.module),
      sensors: Enum.map(projection.sensors, & &1.module),
      plugin: projection.module
    }
  end

  defp projection_module(nil, _key, _id), do: nil

  defp projection_module(projection, :actions, id) do
    projection.actions
    |> Enum.find(&(&1.action_id == id))
    |> case do
      nil -> nil
      action -> action.module
    end
  end

  defp projection_module(projection, :sensors, id) do
    projection.sensors
    |> Enum.find(&(&1.trigger_id == id))
    |> case do
      nil -> nil
      sensor -> sensor.module
    end
  end

  defp tool_entry(%Entry{} = entry, %Tool{} = tool) do
    ToolEntry.new!(%{
      provider: entry.id,
      provider_name: entry.name,
      category: entry.category,
      package: entry.package,
      package_version: entry.version,
      integration_module: entry.module,
      type: tool.type,
      id: tool.id,
      name: tool.name,
      label: tool.label,
      description: tool.description,
      tags: tool.tags,
      module: tool.module,
      resource: tool.resource,
      verb: tool.verb,
      data_classification: tool.data_classification,
      auth_profile: tool.auth_profile,
      auth_profiles: tool.auth_profiles,
      auth_kinds: auth_kinds(entry, tool.auth_profiles),
      policies: tool.policies,
      scopes: tool.scopes,
      risk: tool.risk,
      confirmation: tool.confirmation,
      trigger_kind: tool.trigger_kind,
      source: source(entry)
    })
  end

  defp auth_kinds(%Entry{} = entry, auth_profiles) do
    entry.auth_profiles
    |> Enum.filter(&(&1.id in auth_profiles))
    |> Enum.map(& &1.kind)
    |> Enum.uniq()
  end

  defp source(%Entry{} = entry) do
    (Map.get(entry.metadata, :source) ||
       Map.get(entry.metadata, "source") ||
       bridge_source(entry) ||
       :curated)
    |> normalize_source()
  end

  defp bridge_source(%Entry{} = entry) do
    cond do
      entry.package == :jido_connect_mcp -> :mcp
      :mcp in entry.tags -> :mcp
      Map.get(entry.metadata, :bridge?) -> Map.get(entry.metadata, :bridge_kind, :mcp)
      true -> nil
    end
  end

  defp normalize_source(source) when is_atom(source), do: source

  defp normalize_source(source) when is_binary(source) do
    source
    |> String.trim()
    |> String.to_atom()
  end

  defp package_version(nil), do: nil

  defp package_version(package) when is_atom(package) do
    package
    |> Application.spec(:vsn)
    |> case do
      nil -> nil
      version when is_list(version) -> List.to_string(version)
      version -> to_string(version)
    end
  end

  defp metadata_value(metadata, key) when is_map(metadata) do
    Map.get(metadata, key) || Map.get(metadata, Atom.to_string(key))
  end

  defp metadata_value(_metadata, _key), do: nil
end
