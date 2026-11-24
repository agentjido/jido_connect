defmodule Jido.Connect.Google.Calendar.FixtureTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Calendar.Normalizer
  alias Jido.Connect.Google.TestSupport.ConnectorContracts
  alias Jido.Connect.TestSupport.LiveSmoke

  test "normalizes common Google Calendar event fixture" do
    # events.get of the prepared meeting, recorded from the test account.
    # The expected values come from the recording, so recording event_get
    # again after fresh Meet data leaves this test unchanged.
    %{
      "start" => %{"dateTime" => start},
      "end" => %{"dateTime" => finish},
      "attendees" => [_ | _] = attendees
    } = payload = LiveSmoke.fixture!(:google_calendar, "event_get")

    assert {:ok, event} = Normalizer.event(payload, calendar_id: "primary")
    assert event.event_id == payload["id"]
    assert event.calendar_id == "primary"
    assert event.summary == payload["summary"]
    assert {event.start, event.end} == {start, finish}

    # Google sends the organizer and self flags only when they are true.
    expected =
      Enum.map(attendees, fn attendee ->
        %{
          email: attendee["email"],
          response_status: attendee["responseStatus"],
          organizer?: attendee["organizer"] == true,
          self?: attendee["self"] == true
        }
      end)

    assert Enum.map(event.attendees, &Map.take(&1, Map.keys(hd(expected)))) == expected
  end

  test "normalizes edge Google Calendar freebusy fixture" do
    payload = fixture!("freebusy_edge.json")

    assert {:ok, free_busy} = Normalizer.free_busy(payload)
    assert [%{calendar_id: "primary", start: "2026-05-06T09:00:00Z"}] = free_busy.busy

    assert %{
             target_type: :calendar,
             target_id: "missing@example.com",
             domain: "global",
             reason: "notFound"
           } in free_busy.errors

    assert %{
             target_type: :group,
             target_id: "team@example.com",
             domain: "global",
             reason: "groupTooBig"
           } in free_busy.errors
  end

  defp fixture!(name) do
    ConnectorContracts.google_fixture!(:google_calendar, name, __DIR__)
  end
end
