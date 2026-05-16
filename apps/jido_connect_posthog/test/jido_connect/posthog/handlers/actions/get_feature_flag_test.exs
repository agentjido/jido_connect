defmodule Jido.Connect.PostHog.Handlers.Actions.GetFeatureFlagTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.PostHog.Handlers.Actions.GetFeatureFlag

  describe "run/2" do
    test "fetches a single feature flag by ID" do
      credentials = %{posthog_client: Jido.Connect.PostHog.MockClient, api_key: "token"}

      input = %{flag_id: "42"}

      assert {:ok, result} = GetFeatureFlag.run(input, %{credentials: credentials})
      assert result.id == "42"
      assert result.key == "new-dashboard"
      assert result.name == "New Dashboard"

      assert result.description ==
               "Enable the redesigned dashboard experience for selected users."

      assert result.active == true
      assert result.rollout_percentage == 50.0
      assert is_map(result.filters)
      assert result.created_at == "2026-04-20T09:00:00.000Z"
    end
  end
end
