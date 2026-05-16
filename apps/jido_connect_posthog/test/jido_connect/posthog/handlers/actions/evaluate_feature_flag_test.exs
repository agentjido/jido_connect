defmodule Jido.Connect.PostHog.Handlers.Actions.EvaluateFeatureFlagTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.PostHog.Handlers.Actions.EvaluateFeatureFlag

  describe "run/2" do
    test "evaluates an enabled feature flag" do
      credentials = %{posthog_client: Jido.Connect.PostHog.MockClient, api_key: "token"}

      input = %{
        flag_key: "new-dashboard",
        distinct_id: "user-1"
      }

      assert {:ok, result} = EvaluateFeatureFlag.run(input, %{credentials: credentials})
      assert result.flag_key == "new-dashboard"
      assert result.enabled == true
      assert result.variant == nil
    end

    test "evaluates a feature flag with variant" do
      credentials = %{posthog_client: Jido.Connect.PostHog.MockClient, api_key: "token"}

      input = %{
        flag_key: "dark-mode",
        distinct_id: "user-1"
      }

      assert {:ok, result} = EvaluateFeatureFlag.run(input, %{credentials: credentials})
      assert result.flag_key == "dark-mode"
      assert result.enabled == true
      assert result.variant == "variant-a"
      assert result.payload["color_scheme"] == "dark"
    end

    test "evaluates a disabled feature flag" do
      credentials = %{posthog_client: Jido.Connect.PostHog.MockClient, api_key: "token"}

      input = %{
        flag_key: "disabled-flag",
        distinct_id: "user-1"
      }

      assert {:ok, result} = EvaluateFeatureFlag.run(input, %{credentials: credentials})
      assert result.flag_key == "disabled-flag"
      assert result.enabled == false
      assert result.variant == nil
    end

    test "passes group and person properties" do
      credentials = %{posthog_client: Jido.Connect.PostHog.MockClient, api_key: "token"}

      input = %{
        flag_key: "new-dashboard",
        distinct_id: "user-1",
        groups: %{"company" => "acme"},
        person_properties: %{"plan" => "pro"}
      }

      assert {:ok, result} = EvaluateFeatureFlag.run(input, %{credentials: credentials})
      assert result.flag_key == "new-dashboard"
    end
  end
end
