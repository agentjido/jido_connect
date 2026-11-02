defmodule Jido.Connect.Google.Calendar.LiveEventCreateTest do
  @moduledoc """
  Live check of `google.calendar.event.create` against the Google Workspace
  test account.

      GOOGLE_LIVE_DESTRUCTIVE=true mix test --only live_smoke

  The test creates its events in February 2027, with per-run event IDs, no
  attendees and no notifications, and deletes them at the end and on exit.
  The deletes go through the client and stay out of the recordings.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect.Google.Calendar.Client
  alias Jido.Connect.Google.Calendar.TestSupport.LiveCalendar

  describe "google.calendar.event.create" do
    @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_CALENDAR_ID"])
    @tag write!(:google)
    test "creates a timed and an all-day event that read back by ID", %{env: env} do
      %{"GOOGLE_ACCESS_TOKEN" => token, "GOOGLE_CALENDAR_ID" => calendar_id} = env
      run = LiveCalendar.run_id()
      timed_id = "jcls1t" <> run
      all_day_id = "jcls1a" <> run

      on_exit(fn ->
        LiveCalendar.delete_leftover(calendar_id, timed_id, token)
        LiveCalendar.delete_leftover(calendar_id, all_day_id, token)
      end)

      LiveCalendar.record("event_create")

      assert {:ok, %{event: %{event_id: ^timed_id}}} =
               create(token, %{
                 calendar_id: calendar_id,
                 event_id: timed_id,
                 summary: "jcl-live create timed #{run}",
                 start: "2027-02-01T10:00:00+01:00",
                 end: "2027-02-01T11:15:00+01:00",
                 time_zone: "Europe/Berlin",
                 send_updates: "none"
               })

      assert {:ok, %{event: %{event_id: ^all_day_id}}} =
               create(token, %{
                 calendar_id: calendar_id,
                 event_id: all_day_id,
                 summary: "jcl-live create all-day #{run}",
                 start: "2027-02-02",
                 end: "2027-02-03",
                 all_day: true,
                 send_updates: "none"
               })

      LiveCalendar.record("event_create_get")

      timed = get!(token, calendar_id, timed_id)
      assert same_instant?(timed.start, "2027-02-01T10:00:00+01:00")
      assert same_instant?(timed.end, "2027-02-01T11:15:00+01:00")
      assert timed.start_time_zone == "Europe/Berlin"
      assert timed.end_time_zone == "Europe/Berlin"
      assert timed.all_day? == false

      all_day = get!(token, calendar_id, all_day_id)
      assert all_day.start == "2027-02-02"
      assert all_day.end == "2027-02-03"
      assert all_day.all_day? == true

      LiveCalendar.skip_recording()

      for event_id <- [timed_id, all_day_id] do
        assert {:ok, %{deleted?: true}} =
                 Client.delete_event(
                   %{calendar_id: calendar_id, event_id: event_id, send_updates: "none"},
                   token
                 )
      end
    end
  end

  defp create(token, input) do
    scopes = [LiveCalendar.events_scope()]
    LiveCalendar.invoke("google.calendar.event.create", input, token, scopes)
  end

  defp get!(token, calendar_id, event_id) do
    assert {:ok, %{event: event}} =
             LiveCalendar.invoke(
               "google.calendar.event.get",
               %{calendar_id: calendar_id, event_id: event_id},
               token,
               [LiveCalendar.events_readonly_scope()]
             )

    assert event.event_id == event_id
    event
  end

  defp same_instant?(left, right) do
    {:ok, left, _offset} = DateTime.from_iso8601(left)
    {:ok, right, _offset} = DateTime.from_iso8601(right)
    DateTime.compare(left, right) == :eq
  end
end
