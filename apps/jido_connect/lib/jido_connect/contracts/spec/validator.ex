defmodule Jido.Connect.Spec.Validator do
  @moduledoc false

  alias Jido.Connect.{Authorization, Error, OperationChecks, Schema, Spec, Taxonomy}

  @doc false
  @spec validate!(Spec.t()) :: Spec.t()
  def validate!(%Spec{} = spec) do
    auth_ids = MapSet.new(spec.auth_profiles, & &1.id)
    policy_ids = MapSet.new(spec.policies, & &1.id)

    duplicate_ids!(spec.actions, & &1.id, "action")
    duplicate_ids!(spec.triggers, & &1.id, "trigger")
    duplicate_ids!(spec.policies, & &1.id, "policy")
    duplicate_ids!(spec.schemas, & &1.id, "schema")

    Enum.each(spec.schemas, &Schema.validate_unique_fields!(&1.fields))

    validate_taxonomy!(spec)

    Enum.each(spec.actions, fn action ->
      Schema.validate_unique_fields!(action.input)
      Schema.validate_unique_fields!(action.output)
      validate_operation_taxonomy!(action)
      validate_auth_profiles!(action, auth_ids)
      validate_mutation!(action)
      validate_policy_refs!(action.policies, policy_ids, action.id)
    end)

    Enum.each(spec.triggers, fn trigger ->
      Schema.validate_unique_fields!(trigger.config)
      Schema.validate_unique_fields!(trigger.signal)
      validate_operation_taxonomy!(trigger)
      validate_auth_profiles!(trigger, auth_ids)
      validate_trigger_contract!(trigger)
      validate_policy_refs!(trigger.policies, policy_ids, trigger.id)
    end)

    spec
  end

  defp validate_auth_profiles!(operation, auth_ids) do
    Enum.each(
      OperationChecks.unknown_references(
        Authorization.operation_auth_profiles(operation),
        auth_ids
      ),
      fn auth_profile ->
        raise Error.validation("Unknown auth profile",
                reason: :unknown_auth_profile,
                subject: auth_profile,
                details: %{operation_id: operation.id}
              )
      end
    )

    if operation.auth_profile not in Authorization.operation_auth_profiles(operation) do
      raise Error.validation("Unknown auth profile",
              reason: :unknown_auth_profile,
              subject: operation.auth_profile,
              details: %{operation_id: operation.id}
            )
    end
  end

  defp validate_mutation!(action) do
    if OperationChecks.missing_mutation?(action) do
      raise Error.validation("Write-risk action must declare mutation",
              reason: :mutation_risk_mismatch,
              subject: action.id
            )
    end

    if action.mutation? and OperationChecks.missing_confirmation?(action.confirmation) do
      raise Error.validation("Mutation action must declare confirmation policy",
              reason: :missing_confirmation_policy,
              subject: action.id
            )
    end
  end

  defp validate_trigger_contract!(trigger) do
    if OperationChecks.missing_poll_contract?(trigger) do
      raise Error.validation("Poll trigger must declare checkpoint and dedupe",
              reason: :missing_poll_contract,
              subject: trigger.id
            )
    end

    if OperationChecks.missing_webhook_verification?(trigger) do
      raise Error.validation("Webhook trigger must declare verification",
              reason: :missing_webhook_verification,
              subject: trigger.id
            )
    end
  end

  defp validate_taxonomy!(%Spec{} = spec) do
    validate_known!(
      :category,
      spec.category,
      Taxonomy.categories(),
      spec.id,
      &Taxonomy.known_category?/1
    )

    validate_known!(:status, spec.status, Taxonomy.statuses(), spec.id, &Taxonomy.known_status?/1)

    validate_known!(
      :visibility,
      spec.visibility,
      Taxonomy.visibilities(),
      spec.id,
      &Taxonomy.known_visibility?/1
    )
  end

  defp validate_operation_taxonomy!(operation) do
    validate_required!(:resource, operation)
    validate_required!(:verb, operation)
    validate_required!(:data_classification, operation)

    validate_known!(
      :verb,
      operation.verb,
      Taxonomy.verbs(),
      operation.id,
      &Taxonomy.known_verb?/1
    )

    validate_known!(
      :data_classification,
      operation.data_classification,
      Taxonomy.data_classifications(),
      operation.id,
      &Taxonomy.known_data_classification?/1
    )

    if Map.has_key?(operation, :risk) do
      validate_known!(
        :risk,
        operation.risk,
        Taxonomy.risks(),
        operation.id,
        &Taxonomy.known_risk?/1
      )

      validate_known!(
        :confirmation,
        operation.confirmation,
        Taxonomy.confirmations(),
        operation.id,
        &Taxonomy.known_confirmation?/1
      )
    end
  end

  defp validate_required!(field, operation) do
    if OperationChecks.missing_metadata?(operation, field) do
      raise Error.validation("Operation must declare #{field}",
              reason: :missing_operation_metadata,
              subject: operation.id,
              details: %{field: field}
            )
    end
  end

  defp validate_known!(field, value, allowed, subject, known?) do
    unless known?.(value) do
      raise Error.validation("Unknown #{field}",
              reason: :unknown_taxonomy_value,
              subject: subject,
              details: %{field: field, value: value, allowed: allowed}
            )
    end
  end

  defp validate_policy_refs!(policies, policy_ids, operation_id) do
    Enum.each(OperationChecks.unknown_references(policies, policy_ids), fn policy ->
      raise Error.validation("Unknown policy",
              reason: :unknown_policy,
              subject: policy,
              details: %{operation_id: operation_id}
            )
    end)
  end

  defp duplicate_ids!(items, id_fun, label) do
    ids = Enum.map(items, id_fun)

    case ids -- Enum.uniq(ids) do
      [] ->
        :ok

      duplicates ->
        raise Error.validation("Duplicate #{label} ids",
                reason: :duplicate_id,
                subject: label,
                details: %{duplicates: Enum.uniq(duplicates)}
              )
    end
  end
end
