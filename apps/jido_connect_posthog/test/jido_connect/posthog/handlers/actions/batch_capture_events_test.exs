defmodule Jido.Connect.PostHog.Handlers.Actions.BatchCaptureEventsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.PostHog.Handlers.Actions.BatchCaptureEvents

  describe "run/2" do
    test "captures a batch of events successfully" do
      credentials = %{posthog_client: Jido.Connect.PostHog.MockClient, api_key: "token"}

      events = [
        %{"event" => "pageview", "distinct_id" => "user-1", "properties" => %{"path" => "/home"}},
        %{"event" => "signup", "distinct_id" => "user-2", "properties" => %{"plan" => "pro"}}
      ]

      input = %{events: events}

      assert {:ok, %{status: "captured", count: 2}} =
               BatchCaptureEvents.run(input, %{credentials: credentials})
    end

    test "captures empty batch" do
      credentials = %{posthog_client: Jido.Connect.PostHog.MockClient, api_key: "token"}

      input = %{events: []}

      assert {:ok, %{status: "captured", count: 0}} =
               BatchCaptureEvents.run(input, %{credentials: credentials})
    end
  end
end
