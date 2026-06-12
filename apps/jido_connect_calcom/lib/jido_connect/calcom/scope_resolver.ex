defmodule Jido.Connect.Calcom.ScopeResolver do
  @moduledoc """
  Resolves Cal.com OAuth scopes.

  The scaffold keeps Cal.com scope behavior package-local so later action
  families can choose provider-specific least-privilege scopes without adding
  generic scheduling scope logic to `jido_connect` core.
  """

  @scope_map %{
    "calcom.event_types.list" => ["EVENT_TYPE_READ"],
    "calcom.bookings.list" => ["BOOKING_READ"],
    "calcom.bookings.get" => ["BOOKING_READ"],
    "calcom.bookings.cancel" => ["BOOKING_WRITE"],
    "calcom.bookings.reschedule" => ["BOOKING_WRITE"],
    "calcom.webhooks.list" => ["WEBHOOK_READ"],
    "calcom.webhooks.create" => ["WEBHOOK_WRITE"],
    "calcom.webhooks.delete" => ["WEBHOOK_WRITE"]
  }

  def required_scopes(operation, _input, _connection) do
    operation
    |> operation_id()
    |> then(&Map.get(@scope_map, &1, []))
  end

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(_operation), do: nil
end
