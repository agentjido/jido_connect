defmodule Jido.Connect.Calendly.Handlers.Actions.ListScheduledEventsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly.Handlers.Actions.ListScheduledEvents
  alias Jido.Connect.Calendly.Pagination
  alias Jido.Connect.Calendly.ScheduledEvent

  describe "run/2" do
    test "returns scheduled events list with pagination" do
      events = [
        ScheduledEvent.new!(%{
          uri: "https://api.calendly.com/scheduled_events/ev1",
          name: "Event 1",
          status: "active"
        }),
        ScheduledEvent.new!(%{
          uri: "https://api.calendly.com/scheduled_events/ev2",
          name: "Event 2",
          status: "canceled"
        })
      ]

      pagination =
        Pagination.new!(%{
          next_page: "https://api.calendly.com/scheduled_events?page=2",
          count: 2
        })

      MockClient.stub(list_scheduled_events: {:ok, %{items: events, pagination: pagination}})
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:ok, result} = ListScheduledEvents.run(%{}, %{credentials: credentials})
      assert length(result.scheduled_events) == 2
      assert hd(result.scheduled_events).uri == "https://api.calendly.com/scheduled_events/ev1"
      assert result.pagination.next_page =~ "page=2"
    end

    test "returns scheduled events without pagination" do
      events = [ScheduledEvent.new!(%{uri: "https://api.calendly.com/scheduled_events/ev1"})]
      MockClient.stub(list_scheduled_events: {:ok, %{items: events}})
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:ok, result} = ListScheduledEvents.run(%{}, %{credentials: credentials})
      assert length(result.scheduled_events) == 1
      refute Map.has_key?(result, :pagination)
    end

    test "passes date filters to client" do
      MockClient.stub(list_scheduled_events: {:ok, %{items: []}})
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:ok, _} =
               ListScheduledEvents.run(
                 %{
                   min_start_time: "2026-05-01T00:00:00Z",
                   max_start_time: "2026-05-31T23:59:59Z",
                   status: "active"
                 },
                 %{credentials: credentials}
               )
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :calendly, message: "Unauthorized"}}

      MockClient.stub(list_scheduled_events: error)
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               ListScheduledEvents.run(%{}, %{credentials: credentials})
    end
  end
end
