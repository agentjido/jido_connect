defmodule Jido.Connect.PostHog.Handlers.Actions.CaptureEventTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.PostHog.Handlers.Actions.CaptureEvent

  describe "run/2" do
    test "captures a single event successfully" do
      credentials = %{posthog_client: Jido.Connect.PostHog.MockClient, api_key: "token"}

      input = %{
        event: "pageview",
        distinct_id: "user-1",
        properties: %{"path" => "/home"}
      }

      assert {:ok, %{status: "captured"}} = CaptureEvent.run(input, %{credentials: credentials})
    end

    test "captures an event with timestamp" do
      credentials = %{posthog_client: Jido.Connect.PostHog.MockClient, api_key: "token"}

      input = %{
        event: "pageview",
        distinct_id: "user-1",
        properties: %{},
        timestamp: "2026-05-15T10:00:00.000Z"
      }

      assert {:ok, %{status: "captured"}} = CaptureEvent.run(input, %{credentials: credentials})
    end

    test "captures an event with empty properties" do
      credentials = %{posthog_client: Jido.Connect.PostHog.MockClient, api_key: "token"}

      input = %{
        event: "pageview",
        distinct_id: "user-1"
      }

      assert {:ok, %{status: "captured"}} = CaptureEvent.run(input, %{credentials: credentials})
    end
  end
end
