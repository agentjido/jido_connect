defmodule Jido.Connect.OperationChecks do
  @moduledoc false

  def missing_metadata?(operation, field), do: Map.get(operation, field) in [nil, ""]

  def unknown_references(references, known_ids) do
    references
    |> List.wrap()
    |> Enum.reject(&MapSet.member?(known_ids, &1))
  end

  def mutating_risk?(risk), do: risk not in [:read, :metadata]

  def missing_mutation?(action), do: mutating_risk?(action.risk) and not action.mutation?

  def missing_confirmation?(confirmation), do: confirmation in [nil, :none]

  def unconfirmed_mutating_risk?(risk, confirmation),
    do: mutating_risk?(risk) and missing_confirmation?(confirmation)

  def missing_poll_contract?(%{kind: :poll} = trigger),
    do: is_nil(trigger.checkpoint) or is_nil(trigger.dedupe)

  def missing_poll_contract?(_trigger), do: false

  def missing_webhook_verification?(%{kind: :webhook} = trigger),
    do: not Jido.Connect.WebhookVerification.declared?(trigger.verification)

  def missing_webhook_verification?(_trigger), do: false
end
