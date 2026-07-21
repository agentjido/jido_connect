defmodule Jido.Connect.Calendly.Handlers.Actions.GetScheduledEventTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly.Handlers.Actions.GetScheduledEvent
  alias Jido.Connect.Calendly.ScheduledEvent

  describe "run/2" do
    test "returns scheduled event on success" do
      event =
        ScheduledEvent.new!(%{
          uri: "https://api.calendly.com/scheduled_events/m3n4o5p6",
          name: "30 Minute Meeting",
          status: "active",
          start_time: "2026-05-20T10:00:00.000000Z",
          end_time: "2026-05-20T10:30:00.000000Z"
        })

      MockClient.stub(get_scheduled_event: {:ok, event})
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:ok, %{scheduled_event: result}} =
               GetScheduledEvent.run(
                 %{uri: "https://api.calendly.com/scheduled_events/m3n4o5p6"},
                 %{credentials: credentials}
               )

      assert result.uri == "https://api.calendly.com/scheduled_events/m3n4o5p6"
      assert result.status == "active"
      assert result.start_time == "2026-05-20T10:00:00.000000Z"
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :calendly, message: "Not found"}}

      MockClient.stub(get_scheduled_event: error)
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               GetScheduledEvent.run(
                 %{uri: "https://api.calendly.com/scheduled_events/nonexistent"},
                 %{credentials: credentials}
               )
    end
  end
end
