defmodule Jido.Connect.Google.Calendar.LiveEventChangedPagedTest do
  @moduledoc """
  Live check that the `google.calendar.event.changed` poll drains an
  incremental sync of the Google Workspace test account at two events per
  page. While recording, it also checks that the recorded poll has two pages
  and holds only this run's events.

      GOOGLE_LIVE_DESTRUCTIVE=true mix test --only live_smoke

  The test creates three events in March 2027, with per-run event IDs, no
  attendees and no notifications, and deletes them at the end and on exit.
  The setup writes go through the client and stay out of the recordings.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect.Google.Calendar.Client
  alias Jido.Connect.Google.Calendar.TestSupport.LiveCalendar

  # The full sync at two events per page takes a few dozen requests, and the
  # change poll retries for up to 20 s.
  @moduletag timeout: 300_000

  # Three changes at two per page give an incremental sync of two pages. A
  # sync token belongs to the query it came from, so the initializing poll
  # uses the same page size.
  @page_size 2
  @days ["2027-03-03", "2027-03-04", "2027-03-05"]

  describe "google.calendar.event.changed" do
    @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_CALENDAR_ID"])
    @tag write!(:google)
    test "drains an incremental sync of several pages", %{env: env} do
      %{"GOOGLE_ACCESS_TOKEN" => token, "GOOGLE_CALENDAR_ID" => calendar_id} = env
      run = LiveCalendar.run_id()
      event_ids = for letter <- ["a", "b", "c"], do: "jclr3" <> letter <> run

      on_exit(fn ->
        for event_id <- event_ids, do: LiveCalendar.delete_leftover(calendar_id, event_id, token)
      end)

      config = %{calendar_id: calendar_id, page_size: @page_size}

      LiveCalendar.skip_recording()
      assert {:ok, %{signals: [], checkpoint: checkpoint}} = LiveCalendar.poll(config, nil, token)

      for {event_id, day} <- Enum.zip(event_ids, @days) do
        assert {:ok, _event} =
                 Client.create_event(
                   %{
                     calendar_id: calendar_id,
                     event_id: event_id,
                     summary: "jcl-live paged #{run}",
                     start: "#{day}T10:00:00+01:00",
                     end: "#{day}T10:30:00+01:00",
                     time_zone: "Europe/Berlin",
                     send_updates: "none"
                   },
                   token
                 )
      end

      assert {:ok, %{signals: signals, checkpoint: next}} =
               LiveCalendar.poll_since(
                 "event_changed_paged",
                 config,
                 checkpoint,
                 token,
                 &all_seen?(&1, event_ids)
               )

      assert all_seen?(signals, event_ids)
      assert is_binary(next) and next not in ["", checkpoint]
      LiveCalendar.assert_recorded_poll("event_changed_paged", event_ids, 2)

      LiveCalendar.skip_recording()

      for event_id <- event_ids do
        assert {:ok, %{deleted?: true}} =
                 Client.delete_event(
                   %{calendar_id: calendar_id, event_id: event_id, send_updates: "none"},
                   token
                 )
      end
    end
  end

  defp all_seen?(signals, event_ids) do
    Enum.all?(event_ids, fn event_id ->
      Enum.any?(signals, &(&1.event_id == event_id and &1.change_type == "updated"))
    end)
  end
end
