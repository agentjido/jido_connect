defmodule Jido.Connect.Dsl.SpecBuilder do
  @moduledoc false

  alias Jido.Connect.{
    ActionSpec,
    AuthProfile,
    ConnectorCapability,
    NamedSchema,
    PolicyRequirement,
    Schema,
    Spec,
    TriggerSpec
  }

  alias Jido.Connect.Dsl

  def build(dsl_state, transformer) do
    with {:ok, integration_attrs} <- integration_attrs(dsl_state, transformer) do
      build_spec(dsl_state, transformer, integration_attrs)
    end
  end

  defp integration_attrs(dsl_state, transformer) do
    id = transformer.get_option(dsl_state, [:integration], :id)
    name = transformer.get_option(dsl_state, [:integration], :name)

    if id && name do
      integration_metadata = transformer.get_option(dsl_state, [:integration], :metadata, %{})
      catalog_metadata = transformer.get_option(dsl_state, [:catalog], :metadata, %{})

      {:ok,
       %{
         id: id,
         name: name,
         description:
           transformer.get_option(dsl_state, [:catalog], :description) ||
             transformer.get_option(dsl_state, [:integration], :description),
         category: transformer.get_option(dsl_state, [:integration], :category),
         package: transformer.get_option(dsl_state, [:catalog], :package),
         status: transformer.get_option(dsl_state, [:catalog], :status, :available),
         tags: transformer.get_option(dsl_state, [:catalog], :tags, []),
         visibility: transformer.get_option(dsl_state, [:catalog], :visibility, :public),
         docs: transformer.get_option(dsl_state, [:integration], :docs, []),
         metadata: Map.merge(integration_metadata, catalog_metadata)
       }}
    else
      {:error,
       Spark.Error.DslError.exception(
         module: transformer.get_persisted(dsl_state, :module),
         path: [:integration],
         message: "integration section with id and name is required"
       )}
    end
  end

  defp build_spec(dsl_state, transformer, integration_attrs) do
    auth_profiles =
      dsl_state
      |> transformer.get_entities([:auth])
      |> Enum.map(fn profile ->
        build_entity!(dsl_state, transformer, [:auth, profile.id], fn ->
          auth_profile!(profile)
        end)
      end)

    capabilities =
      dsl_state
      |> transformer.get_entities([:catalog])
      |> Enum.map(fn capability ->
        build_entity!(dsl_state, transformer, [:catalog, capability.name], fn ->
          capability!(capability, integration_attrs)
        end)
      end)

    policies =
      dsl_state
      |> transformer.get_entities([:policies])
      |> Enum.map(fn policy ->
        build_entity!(dsl_state, transformer, [:policies, policy.name], fn ->
          policy_requirement!(policy)
        end)
      end)

    schemas =
      dsl_state
      |> transformer.get_entities([:schemas])
      |> Enum.map(fn schema ->
        build_entity!(dsl_state, transformer, [:schemas, schema.name], fn ->
          named_schema!(schema)
        end)
      end)

    schemas_by_id = Map.new(schemas, &{&1.id, &1})

    actions =
      dsl_state
      |> transformer.get_entities([:actions])
      |> Enum.map(fn action ->
        build_entity!(dsl_state, transformer, [:actions, action.name], fn ->
          action_spec!(action, integration_attrs.id, schemas_by_id, auth_profiles)
        end)
      end)

    triggers =
      dsl_state
      |> transformer.get_entities([:triggers])
      |> Enum.map(fn trigger ->
        build_entity!(dsl_state, transformer, [:triggers, trigger.name], fn ->
          trigger_spec!(trigger, integration_attrs.id, schemas_by_id, auth_profiles)
        end)
      end)

    spec =
      integration_attrs
      |> Map.put(:capabilities, capabilities)
      |> Map.put(:policies, policies)
      |> Map.put(:schemas, schemas)
      |> Map.put(:auth_profiles, auth_profiles)
      |> Map.put(:actions, actions)
      |> Map.put(:triggers, triggers)
      |> Spec.new!()

    {:ok, spec}
  rescue
    error in [Spark.Error.DslError] ->
      {:error, error}

    error ->
      {:error, dsl_error(dsl_state, transformer, [], error)}
  end

  defp build_entity!(dsl_state, transformer, path, fun) do
    fun.()
  rescue
    error in [Spark.Error.DslError] ->
      raise error

    error ->
      raise dsl_error(dsl_state, transformer, path, error)
  end

  defp dsl_error(dsl_state, transformer, path, error) do
    Spark.Error.DslError.exception(
      module: transformer.get_persisted(dsl_state, :module),
      path: path,
      message: error
    )
  end

  defp auth_profile!(%Dsl.AuthProfile{} = profile) do
    attrs = Map.from_struct(profile)
    credential_fields = credential_fields(attrs)

    attrs
    |> Map.put(:credential_fields, credential_fields)
    |> Map.put(:lease_fields, non_empty(attrs.lease_fields, credential_fields))
    |> Map.put(:fields, credential_fields)
    |> Map.put(:setup, attrs.setup || setup_for(attrs.kind))
    |> AuthProfile.new!()
  end

  defp capability!(%Dsl.Capability{} = capability, integration_attrs) do
    ConnectorCapability.new!(%{
      id: capability.id || "#{integration_attrs.id}.#{capability.name}",
      provider: integration_attrs.id,
      kind: capability.kind,
      feature: capability.feature || capability.name,
      label: capability.label || humanize(capability.name),
      description: capability.description,
      status: capability.status || integration_attrs.status || :available,
      metadata: capability.metadata
    })
  end

  defp policy_requirement!(%Dsl.PolicyRequirement{} = policy) do
    PolicyRequirement.new!(%{
      id: policy.id || policy.name,
      label: policy.label || humanize(policy.name),
      description: policy.description,
      subject: policy.subject,
      owner: policy.owner,
      decision: policy.decision,
      metadata: policy.metadata
    })
  end

  defp named_schema!(%Dsl.NamedSchema{} = schema) do
    fields = fields(schema.fields)

    NamedSchema.new!(%{
      id: schema.name,
      label: schema.label || humanize(schema.name),
      description: schema.description,
      fields: fields,
      zoi_schema: Schema.zoi_schema_from_fields(fields),
      metadata: schema.metadata
    })
  end

  defp action_spec!(%Dsl.Action{} = action, integration_id, schemas_by_id, provider_auth_profiles) do
    input = fields(action.input, action.input_schema, schemas_by_id, :input, action.name)
    output = fields(action.output, action.output_schema, schemas_by_id, :output, action.name)
    default_auth_profile = default_auth_profile(provider_auth_profiles)
    {auth_profile, auth_profiles} = auth_profiles(access_auth(action), default_auth_profile)
    requirements = requirements(action.requirements, action.access)
    policies = access_policies(action)
    {mutation?, risk, confirmation} = effect(action)

    ActionSpec.new!(%{
      id: action.id || "#{integration_id}.#{action.name}",
      name: action.name,
      label: action.label || humanize(action.name),
      description: action.description,
      resource: action.resource,
      verb: action.verb,
      data_classification: action.data_classification,
      auth_profile: auth_profile,
      auth_profiles: auth_profiles,
      policies: policies,
      handler: action.handler,
      input: input,
      output: output,
      input_schema: Schema.zoi_schema_from_fields(input),
      output_schema: Schema.zoi_schema_from_fields(output),
      scopes: requirements.scopes,
      scope_resolver: requirements.dynamic_scopes,
      mutation?: mutation?,
      risk: risk,
      confirmation: confirmation,
      metadata: action.metadata
    })
  end

  defp trigger_spec!(
         %Dsl.Trigger{} = trigger,
         integration_id,
         schemas_by_id,
         provider_auth_profiles
       ) do
    config = fields(trigger.config, trigger.config_schema, schemas_by_id, :config, trigger.name)
    signal = fields(trigger.signal, trigger.signal_schema, schemas_by_id, :signal, trigger.name)
    default_auth_profile = default_auth_profile(provider_auth_profiles)
    {auth_profile, auth_profiles} = auth_profiles(access_auth(trigger), default_auth_profile)
    requirements = requirements(trigger.requirements, trigger.access)
    policies = access_policies(trigger)

    TriggerSpec.new!(%{
      id: trigger.id || "#{integration_id}.#{trigger.name}",
      name: trigger.name,
      kind: trigger.kind,
      label: trigger.label || humanize(trigger.name),
      description: trigger.description,
      resource: trigger.resource,
      verb: trigger.verb,
      data_classification: trigger.data_classification,
      auth_profile: auth_profile,
      auth_profiles: auth_profiles,
      policies: policies,
      handler: trigger.handler,
      config: config,
      signal: signal,
      config_schema: Schema.zoi_schema_from_fields(config),
      signal_schema: Schema.zoi_schema_from_fields(signal),
      scopes: requirements.scopes,
      scope_resolver: requirements.dynamic_scopes,
      verification: trigger.verification || %{kind: :none},
      dedupe: trigger.dedupe,
      checkpoint: trigger.checkpoint,
      interval_ms: trigger.interval_ms,
      metadata: trigger.metadata
    })
  end

  defp default_auth_profile([]), do: :user

  defp default_auth_profile(auth_profiles) do
    default_profile = Enum.find(auth_profiles, & &1.default?)
    (default_profile || List.first(auth_profiles)).id
  end

  defp auth_profiles(%Dsl.AuthProfiles{profiles: profiles, default: default}, fallback) do
    profiles = List.wrap(profiles || [])
    primary = default || List.first(profiles) || fallback

    {primary,
     [primary | profiles]
     |> Enum.reject(&is_nil/1)
     |> Enum.uniq()}
  end

  defp auth_profiles(nil, fallback), do: {fallback, [fallback]}

  defp requirements(%Dsl.Requirements{} = requirements, _access), do: requirements

  defp requirements(nil, %Dsl.Access{scopes: %Dsl.ScopeRequirements{} = scopes}) do
    %Dsl.Requirements{scopes: scopes.scopes, dynamic_scopes: scopes.resolver}
  end

  defp requirements(nil, _access) do
    %Dsl.Requirements{scopes: [], dynamic_scopes: nil}
  end

  defp access_auth(%{access: %Dsl.Access{auth: %Dsl.AuthProfiles{} = auth}}), do: auth
  defp access_auth(%{auth_profiles: %Dsl.AuthProfiles{} = auth}), do: auth
  defp access_auth(_operation), do: nil

  defp access_policies(%{access: %Dsl.Access{policies: policies}}) when policies != [],
    do: policies

  defp access_policies(%{policies: policies}), do: policies

  defp effect(%Dsl.Action{effect: %Dsl.Effect{} = effect}) do
    risk = effect.risk || :read
    mutation? = if is_nil(effect.mutation?), do: mutating_risk?(risk), else: effect.mutation?
    confirmation = effect.confirmation || if(mutation?, do: :required_for_ai, else: :none)

    {mutation?, risk, confirmation}
  end

  defp effect(%Dsl.Action{} = action), do: {action.mutation?, action.risk, action.confirmation}

  defp mutating_risk?(risk), do: risk not in [:read, :metadata]

  defp credential_fields(attrs) do
    attrs.credential_fields
    |> non_empty(attrs.fields || [])
    |> non_empty([attrs.token_field, attrs.refresh_token_field])
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp non_empty(value, fallback) when value in [nil, []], do: fallback || []
  defp non_empty(value, _fallback), do: value

  defp setup_for(:oauth2), do: :oauth2_authorization_code
  defp setup_for(:app_installation), do: :app_installation
  defp setup_for(:api_key), do: :api_key
  defp setup_for(:service_account), do: :service_account
  defp setup_for(:domain_delegated_service_account), do: :domain_delegated_service_account
  defp setup_for(:none), do: :none

  defp fields(%Dsl.FieldGroup{fields: fields}), do: fields || []
  defp fields(nil), do: []
  defp fields(fields) when is_list(fields), do: fields

  defp fields(inline_fields, schema_ref, schemas_by_id, field_group, operation_name) do
    inline_fields = fields(inline_fields)

    cond do
      is_nil(schema_ref) ->
        inline_fields

      inline_fields != [] ->
        raise ArgumentError,
              "#{field_group} for #{operation_name} cannot declare both inline fields and schema #{inspect(schema_ref)}"

      schema = Map.get(schemas_by_id, schema_ref) ->
        schema.fields

      true ->
        raise ArgumentError,
              "Unknown schema #{inspect(schema_ref)} referenced by #{field_group} for #{operation_name}"
    end
  end

  defp humanize(value) do
    value
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
