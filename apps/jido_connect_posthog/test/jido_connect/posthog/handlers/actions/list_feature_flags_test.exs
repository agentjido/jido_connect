defmodule Jido.Connect.PostHog.Handlers.Actions.ListFeatureFlagsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.PostHog.Handlers.Actions.ListFeatureFlags

  describe "run/2" do
    test "lists feature flags" do
      credentials = %{posthog_client: Jido.Connect.PostHog.MockClient, api_key: "token"}

      input = %{limit: 100, offset: 0}

      assert {:ok, result} = ListFeatureFlags.run(input, %{credentials: credentials})
      assert length(result.flags) == 2

      first = Enum.at(result.flags, 0)
      assert first["key"] == "new-dashboard"
      assert first["name"] == "New Dashboard"
      assert first["active"] == true

      second = Enum.at(result.flags, 1)
      assert second["key"] == "dark-mode"
      assert second["active"] == true

      assert result.next == nil
    end

    test "passes limit and offset options" do
      credentials = %{posthog_client: Jido.Connect.PostHog.MockClient, api_key: "token"}

      input = %{limit: 10, offset: 5}

      assert {:ok, result} = ListFeatureFlags.run(input, %{credentials: credentials})
      assert is_list(result.flags)
    end
  end
end
