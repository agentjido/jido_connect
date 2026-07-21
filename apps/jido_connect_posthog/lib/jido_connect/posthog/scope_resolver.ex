defmodule Jido.Connect.PostHog.ScopeResolver do
  @moduledoc """
  Resolves PostHog API scopes.

  Each action maps to the narrowest set of PostHog scopes required.
  The resolver is consulted by the `access` block at runtime.
  """

  @scope_map %{
    "posthog.event.list" => ["events:read"],
    "posthog.event.get" => ["events:read"],
    "posthog.event.capture" => ["events:write"],
    "posthog.event.batch_capture" => ["events:write"],
    "posthog.person.list" => ["persons:read"],
    "posthog.person.get" => ["persons:read"],
    "posthog.insight.list" => ["insights:read"],
    "posthog.insight.get" => ["insights:read"],
    "posthog.feature_flag.evaluate" => ["feature_flags:read"],
    "posthog.feature_flag.list" => ["feature_flags:read"],
    "posthog.feature_flag.get" => ["feature_flags:read"],
    "posthog.query.run" => ["insights:read"]
  }

  @doc """
  Returns the least-privilege PostHog scopes for the given operation.
  """
  def required_scopes(operation, _input, _connection) do
    operation
    |> operation_id()
    |> then(&Map.get(@scope_map, &1, []))
  end

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(_operation), do: nil
end
