defmodule Jido.Connect.Dsl.OperationRules do
  @moduledoc false

  alias Jido.Connect.Dsl

  def violations(dsl_state, accessor) do
    module = accessor.get_persisted(dsl_state, :module)
    auth_ids = dsl_state |> accessor.get_entities([:auth]) |> MapSet.new(& &1.id)

    policy_ids =
      dsl_state |> accessor.get_entities([:policies]) |> MapSet.new(&(&1.id || &1.name))

    action_violations =
      dsl_state
      |> accessor.get_entities([:actions])
      |> Enum.flat_map(&action_violations(module, &1, auth_ids, policy_ids))

    trigger_violations =
      dsl_state
      |> accessor.get_entities([:triggers])
      |> Enum.flat_map(&trigger_violations(module, &1, auth_ids, policy_ids))

    action_violations ++ trigger_violations
  end

  def dsl_error(%{module: module, path: path, entity: entity, message: message}) do
    Spark.Error.DslError.exception(
      module: module,
      path: path,
      message: message,
      location: Spark.Dsl.Entity.anno(entity)
    )
  end

  defp action_violations(module, %Dsl.Action{} = action, auth_ids, policy_ids) do
    common_violations(module, [:actions], action, auth_ids, policy_ids) ++
      access_compatibility_violations(module, [:actions], action) ++
      effect_compatibility_violations(module, action) ++
      mutating_effect_violations(module, action)
  end

  defp trigger_violations(module, %Dsl.Trigger{} = trigger, auth_ids, policy_ids) do
    common_violations(module, [:triggers], trigger, auth_ids, policy_ids) ++
      access_compatibility_violations(module, [:triggers], trigger) ++
      trigger_shape_violations(module, trigger)
  end

  defp common_violations(module, path, operation, auth_ids, policy_ids) do
    [
      missing_metadata_violation(
        module,
        path,
        operation,
        :resource,
        "Operation must declare resource"
      ),
      missing_metadata_violation(module, path, operation, :verb, "Operation must declare verb"),
      missing_metadata_violation(
        module,
        path,
        operation,
        :data_classification,
        "Operation must declare data_classification"
      )
    ]
    |> Enum.reject(&is_nil/1)
    |> Kernel.++(unknown_auth_profile_violations(module, path, operation, auth_ids))
    |> Kernel.++(unknown_policy_violations(module, path, operation, policy_ids))
  end

  defp missing_metadata_violation(module, path, operation, field, message) do
    if is_nil(Map.get(operation, field)) do
      violation(module, path ++ [operation.name], operation, message)
    end
  end

  defp unknown_auth_profile_violations(module, path, operation, auth_ids) do
    operation
    |> operation_auth_profiles()
    |> Enum.reject(&MapSet.member?(auth_ids, &1))
    |> Enum.map(fn auth_profile ->
      violation(
        module,
        path ++ [operation.name],
        operation,
        "Unknown auth profile #{inspect(auth_profile)}"
      )
    end)
  end

  defp unknown_policy_violations(module, path, operation, policy_ids) do
    operation
    |> operation_policies()
    |> Enum.reject(&MapSet.member?(policy_ids, &1))
    |> Enum.map(fn policy ->
      violation(
        module,
        path ++ [operation.name],
        operation,
        "Unknown policy #{inspect(policy)}"
      )
    end)
  end

  defp access_compatibility_violations(
         module,
         path,
         %{access: %Dsl.Access{} = access} = operation
       ) do
    cond do
      operation.auth_profiles ->
        [
          violation(
            module,
            path ++ [operation.name],
            operation,
            "Do not mix access with legacy auth_profiles"
          )
        ]

      operation.requirements ->
        [
          violation(
            module,
            path ++ [operation.name],
            operation,
            "Do not mix access with legacy requirements"
          )
        ]

      operation.policies != [] && access.policies != [] ->
        [
          violation(
            module,
            path ++ [operation.name],
            operation,
            "Do not mix access with legacy policies"
          )
        ]

      true ->
        []
    end
  end

  defp access_compatibility_violations(_module, _path, _operation), do: []

  defp effect_compatibility_violations(module, %Dsl.Action{effect: %Dsl.Effect{}} = action) do
    if action.mutation? || action.risk != :read || action.confirmation != :none do
      [
        violation(
          module,
          [:actions, action.name],
          action,
          "Do not mix effect with legacy risk settings"
        )
      ]
    else
      []
    end
  end

  defp effect_compatibility_violations(_module, _action), do: []

  defp mutating_effect_violations(module, %Dsl.Action{effect: %Dsl.Effect{} = effect} = action) do
    if mutating_risk?(effect.risk) && effect.confirmation in [nil, :none] do
      [
        violation(
          module,
          [:actions, action.name],
          action,
          "Mutating effect must declare confirmation"
        )
      ]
    else
      []
    end
  end

  defp mutating_effect_violations(_module, _action), do: []

  defp trigger_shape_violations(module, %Dsl.Trigger{kind: :poll} = trigger) do
    if is_nil(trigger.checkpoint) || is_nil(trigger.dedupe) do
      [
        violation(
          module,
          [:triggers, trigger.name],
          trigger,
          "Poll trigger must declare checkpoint and dedupe"
        )
      ]
    else
      []
    end
  end

  defp trigger_shape_violations(module, %Dsl.Trigger{kind: :webhook} = trigger) do
    unless Jido.Connect.WebhookVerification.declared?(trigger.verification) do
      [
        violation(
          module,
          [:triggers, trigger.name],
          trigger,
          "Webhook trigger must declare verification"
        )
      ]
    else
      []
    end
  end

  defp trigger_shape_violations(_module, _trigger), do: []

  defp operation_auth_profiles(%{access: %Dsl.Access{auth: %Dsl.AuthProfiles{} = auth}}),
    do: List.wrap(auth.profiles)

  defp operation_auth_profiles(%{auth_profiles: %Dsl.AuthProfiles{} = auth}),
    do: List.wrap(auth.profiles)

  defp operation_auth_profiles(_operation), do: []

  defp operation_policies(%{access: %Dsl.Access{policies: policies}}) when policies != [],
    do: policies

  defp operation_policies(%{policies: policies}), do: policies

  defp mutating_risk?(risk), do: risk not in [:read, :metadata]

  defp violation(module, path, entity, message) do
    %{module: module, path: path, entity: entity, message: message}
  end
end
