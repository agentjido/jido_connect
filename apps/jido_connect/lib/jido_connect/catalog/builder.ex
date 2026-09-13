defmodule Jido.Connect.Catalog.Builder do
  @moduledoc false

  alias Jido.Connect.{
    ActionSpec,
    AuthProfile,
    ConnectorCapability,
    PolicyRequirement,
    Schema,
    Spec,
    TriggerSpec
  }

  alias Jido.Connect.Catalog.{AuthProfileSummary, Entry, Item, Manifest, Tool, ToolEntry}

  @spec entry(module(), keyword()) :: Entry.t()
  def entry(integration_module, opts \\ []) when is_atom(integration_module) do
    spec = integration_module.integration()
    projection = projection(integration_module)

    entry_from_spec(spec, integration_module, projection, opts)
  end

  @spec entry_from_spec(Jido.Connect.Spec.t(), module(), term(), keyword()) :: Entry.t()
  def entry_from_spec(spec, integration_module, projection, opts \\ []) do
    package = spec_package(spec)

    Entry.new!(%{
      id: spec.id,
      name: spec.name,
      description: spec.description,
      category: spec.category,
      package: package,
      version: spec_version(spec, package, opts),
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
    package = spec_package(spec)

    Entry.new!(%{
      id: spec.id,
      name: spec.name,
      description: spec.description,
      category: spec.category,
      package: package,
      version: spec_version(spec, package, opts),
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

  @doc false
  @spec items(module(), keyword()) :: [Item.t()]
  def items(integration_module, opts \\ []) when is_atom(integration_module) do
    spec = integration_module.integration()
    items_from_spec(spec, integration_module, projection(integration_module), opts)
  end

  @doc false
  @spec items_from_spec(Spec.t(), module(), term(), keyword()) :: [Item.t()]
  def items_from_spec(%Spec{} = spec, integration_module, projection, opts \\ []) do
    package = spec_package(spec)
    version = spec_version(spec, package, opts)

    status =
      Keyword.get(
        opts,
        :status,
        spec.status || metadata_value(spec.metadata, :status) || :available
      )

    provider = provider_metadata(spec, integration_module, package, version, status)
    source = item_source(spec, package)

    Enum.map(spec.actions, fn action ->
      action_item(spec, action, integration_module, projection, provider, source)
    end) ++
      Enum.map(spec.triggers, fn trigger ->
        trigger_item(spec, trigger, integration_module, projection, provider, source)
      end)
  end

  defp action_item(
         %Spec{} = spec,
         %ActionSpec{} = action,
         integration_module,
         projection,
         provider,
         source
       ) do
    input_json_schema =
      Schema.to_json_schema(
        action.input_schema,
        action.input,
        action.input_json_schema_overlay
      )

    output_json_schema = Schema.to_json_schema(action.output_schema)
    auth = operation_auth_summaries(spec, action)

    Item.new!(%{
      ref: Item.ref(spec.id, :action, action.id),
      provider: spec.id,
      provider_name: spec.name,
      provider_metadata: provider,
      category: spec.category,
      package: provider.package,
      package_version: provider.version,
      integration_module: integration_module,
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
      effect: action.risk,
      availability: provider.status,
      auth_profile: action.auth_profile,
      auth_profiles: operation_auth_profiles(action),
      auth_kinds: Enum.map(auth, & &1.kind) |> Enum.uniq(),
      auth: auth,
      policies: operation_policies(spec, action.policies),
      host_policy_required?: action.host_policy_required?,
      scopes: action.scopes,
      risk: action.risk,
      confirmation: action.confirmation,
      input: action.input,
      output: action.output,
      input_json_schema: input_json_schema,
      output_json_schema: output_json_schema,
      schema_digest: schema_digest(input_json_schema, output_json_schema),
      strict?: strict?(input_json_schema, output_json_schema),
      provider_idempotency?: action.provider_idempotency?,
      source: source,
      metadata: Map.merge(spec.metadata, action.metadata)
    })
  end

  defp trigger_item(
         %Spec{} = spec,
         %TriggerSpec{} = trigger,
         integration_module,
         projection,
         provider,
         source
       ) do
    config_json_schema = Schema.to_json_schema(trigger.config_schema)
    signal_json_schema = Schema.to_json_schema(trigger.signal_schema)
    auth = operation_auth_summaries(spec, trigger)

    Item.new!(%{
      ref: Item.ref(spec.id, :trigger, trigger.id),
      provider: spec.id,
      provider_name: spec.name,
      provider_metadata: provider,
      category: spec.category,
      package: provider.package,
      package_version: provider.version,
      integration_module: integration_module,
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
      availability: provider.status,
      auth_profile: trigger.auth_profile,
      auth_profiles: operation_auth_profiles(trigger),
      auth_kinds: Enum.map(auth, & &1.kind) |> Enum.uniq(),
      auth: auth,
      policies: operation_policies(spec, trigger.policies),
      host_policy_required?: trigger.host_policy_required?,
      scopes: trigger.scopes,
      trigger_kind: trigger.kind,
      config: trigger.config,
      signal: trigger.signal,
      input_json_schema: config_json_schema,
      output_json_schema: signal_json_schema,
      config_json_schema: config_json_schema,
      signal_json_schema: signal_json_schema,
      schema_digest: schema_digest(config_json_schema, signal_json_schema),
      strict?: strict?(config_json_schema, signal_json_schema),
      source: source,
      metadata: Map.merge(spec.metadata, trigger.metadata)
    })
  end

  defp operation_auth_summaries(%Spec{} = spec, operation) do
    allowed_profiles = operation_auth_profiles(operation)

    spec.auth_profiles
    |> Enum.filter(&(&1.id in allowed_profiles))
    |> Enum.map(&auth_summary/1)
  end

  defp operation_policies(%Spec{} = spec, policy_ids) do
    Enum.filter(spec.policies, fn
      %PolicyRequirement{id: id} -> id in policy_ids
      _other -> false
    end)
  end

  defp schema_digest(input_json_schema, output_json_schema) do
    Schema.digest(%{"input" => input_json_schema, "output" => output_json_schema})
  end

  defp strict?(input_json_schema, output_json_schema) do
    Schema.strict_object?(input_json_schema) and Schema.strict_object?(output_json_schema)
  end

  defp provider_metadata(spec, integration_module, package, version, status) do
    %{
      id: spec.id,
      name: spec.name,
      description: spec.description,
      category: spec.category,
      package: package,
      module: inspect(integration_module),
      status: status,
      tags: spec.tags,
      visibility: spec.visibility,
      docs: spec.docs,
      version: version
    }
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

  defp item_source(%Spec{} = spec, package) do
    (metadata_value(spec.metadata, :source) ||
       item_bridge_source(spec, package) ||
       :curated)
    |> normalize_source()
  end

  defp item_bridge_source(%Spec{} = spec, _package) do
    cond do
      :mcp in spec.tags ->
        :mcp

      metadata_value(spec.metadata, :bridge?) ->
        metadata_value(spec.metadata, :bridge_kind) || :mcp

      true ->
        nil
    end
  end

  defp bridge_source(%Entry{} = entry) do
    cond do
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

  defp package_version(package) when is_binary(package) do
    package
    |> normalize_package()
    |> package_version()
  end

  defp spec_package(%{package: package, metadata: metadata}) do
    normalize_package(package) || normalize_package(metadata_value(metadata, :package))
  end

  defp spec_version(spec, package, opts) do
    Keyword.get(opts, :version) || metadata_value(spec.metadata, :version) ||
      package_version(package)
  end

  defp normalize_package(package) when is_atom(package), do: package

  defp normalize_package(package) when is_binary(package) do
    package
    |> String.trim()
    |> String.to_existing_atom()
  rescue
    ArgumentError -> nil
  end

  defp normalize_package(_package), do: nil

  defp metadata_value(metadata, key) when is_map(metadata) do
    Map.get(metadata, key) || Map.get(metadata, Atom.to_string(key))
  end

  defp metadata_value(_metadata, _key), do: nil
end
