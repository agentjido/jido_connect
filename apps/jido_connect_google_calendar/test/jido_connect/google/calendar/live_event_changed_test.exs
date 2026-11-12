defmodule Jido.Connect.Google.Calendar.LiveEventChangedTest do
  @moduledoc """
  Live checks of the `google.calendar.event.changed` poll against the Google
  Workspace test account.

      GOOGLE_LIVE_DESTRUCTIVE=true mix test --only live_smoke

  Each test creates, edits and deletes its own events in January 2027, with
  per-run event IDs and no attendees, and deletes what is left on exit. The
  poll itself runs under the trigger's read-only scope; the setup writes go
  through the client and stay out of the recordings.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect.Google.Calendar.Client
  alias Jido.Connect.Google.Calendar.TestSupport.LiveCalendar

  # Google's incremental sync can trail a write by a few seconds.
  @poll_attempts 10
  @poll_pause_ms 2_000

  # The cancellation test polls in five steps; with every attempt used, the
  # pauses alone take 90 s, past ExUnit's default timeout of 60 s.
  @moduletag timeout: 300_000

  # FREQ=WEEKLY;COUNT=3 from 2027-01-11 08:00 Berlin: instance ID suffixes in
  # UTC and the original start of each occurrence.
  @series_occurrences [
    {"20270111T070000Z", "2027-01-11T08:00:00+01:00"},
    {"20270118T070000Z", "2027-01-18T08:00:00+01:00"},
    {"20270125T070000Z", "2027-01-25T08:00:00+01:00"}
  ]

  describe "google.calendar.event.changed" do
    @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_CALENDAR_ID"])
    @tag write!(:google)
    test "emits nothing on initialization, then a creation, an edit and a cancellation", %{
      env: env
    } do
      %{"GOOGLE_ACCESS_TOKEN" => token, "GOOGLE_CALENDAR_ID" => calendar_id} = env
      run = LiveCalendar.run_id()
      event_id = "jcle1" <> run
      on_exit(fn -> LiveCalendar.delete_leftover(calendar_id, event_id, token) end)
      config = %{calendar_id: calendar_id}

      LiveCalendar.record("event_changed_init")
      assert {:ok, %{signals: [], checkpoint: checkpoint}} = LiveCalendar.poll(config, nil, token)
      assert is_binary(checkpoint) and checkpoint != ""

      summary = "jcl-live poll #{run}"
      LiveCalendar.skip_recording()

      assert {:ok, _event} =
               Client.create_event(
                 %{
                   calendar_id: calendar_id,
                   event_id: event_id,
                   summary: summary,
                   start: "2027-01-04T10:00:00+01:00",
                   end: "2027-01-04T10:30:00+01:00",
                   time_zone: "Europe/Berlin",
                   send_updates: "none"
                 },
                 token
               )

      {seen, checkpoint} =
        poll_for(
          "event_changed_created",
          config,
          checkpoint,
          token,
          [event_id],
          &(&1.change_type == "updated")
        )

      assert [%{change_type: "updated", status: "confirmed", summary: ^summary} = created] = seen

      edited_summary = summary <> " edited"
      LiveCalendar.skip_recording()

      assert {:ok, _event} =
               Client.update_event(
                 %{
                   calendar_id: calendar_id,
                   event_id: event_id,
                   summary: edited_summary,
                   send_updates: "none"
                 },
                 token
               )

      {seen, checkpoint} =
        poll_for(
          "event_changed_edited",
          config,
          checkpoint,
          token,
          [event_id],
          &(&1.summary == edited_summary)
        )

      assert [%{change_type: "updated", status: "confirmed", summary: ^edited_summary} = edited] =
               seen

      assert DateTime.compare(instant(edited.updated), instant(created.updated)) == :gt

      LiveCalendar.skip_recording()
      assert {:ok, %{deleted?: true}} = delete_event(calendar_id, event_id, token)

      {seen, _checkpoint} =
        poll_for("event_changed_cancelled", config, checkpoint, token, [event_id], &cancelled?/1)

      assert [%{change_type: "cancelled", status: "cancelled"}] = seen
    end

    @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_CALENDAR_ID"])
    @tag write!(:google)
    test "sees a removed event and a cancelled recurring occurrence and series", %{env: env} do
      %{"GOOGLE_ACCESS_TOKEN" => token, "GOOGLE_CALENDAR_ID" => calendar_id} = env
      run = LiveCalendar.run_id()
      single_id = "jcle2s" <> run
      master_id = "jcle2r" <> run

      [first, second, third] =
        for {suffix, original_start} <- @series_occurrences,
            do: %{id: "#{master_id}_#{suffix}", original_start: original_start}

      on_exit(fn ->
        LiveCalendar.delete_leftover(calendar_id, single_id, token)
        LiveCalendar.delete_leftover(calendar_id, master_id, token)
      end)

      LiveCalendar.skip_recording()

      assert {:ok, _event} =
               Client.create_event(
                 %{
                   calendar_id: calendar_id,
                   event_id: single_id,
                   summary: "jcl-live removed #{run}",
                   start: "2027-01-05T10:00:00+01:00",
                   end: "2027-01-05T10:30:00+01:00",
                   time_zone: "Europe/Berlin",
                   send_updates: "none"
                 },
                 token
               )

      assert {:ok, _event} =
               Client.create_event(
                 %{
                   calendar_id: calendar_id,
                   event_id: master_id,
                   summary: "jcl-live series #{run}",
                   start: "2027-01-11T08:00:00+01:00",
                   end: "2027-01-11T08:30:00+01:00",
                   time_zone: "Europe/Berlin",
                   recurrence: ["RRULE:FREQ=WEEKLY;COUNT=3"],
                   send_updates: "none"
                 },
                 token
               )

      # A sync token is bound to its query, so expanded occurrences and the
      # series master each get their own checkpoint chain.
      expanded = %{calendar_id: calendar_id}
      unexpanded = %{calendar_id: calendar_id, single_events: false}

      # The expanded initialization is the same full sync as in the first
      # test, so only the unexpanded one is recorded.
      assert {:ok, %{signals: [], checkpoint: expanded_cp}} =
               LiveCalendar.poll(expanded, nil, token)

      LiveCalendar.record("event_cancelled_init_unexpanded")

      assert {:ok, %{signals: [], checkpoint: unexpanded_cp}} =
               LiveCalendar.poll(unexpanded, nil, token)

      # A removed single event.
      LiveCalendar.skip_recording()
      assert {:ok, %{deleted?: true}} = delete_event(calendar_id, single_id, token)

      {seen, expanded_cp} =
        poll_for(
          "event_cancelled_removed",
          expanded,
          expanded_cp,
          token,
          [single_id],
          &cancelled?/1
        )

      removed = cancelled_signal!(seen, single_id)
      assert removed.event.recurring_event_id == nil

      # One cancelled occurrence: an expanded instance on one chain, an
      # exception of the master on the other.
      LiveCalendar.skip_recording()
      assert {:ok, %{deleted?: true}} = delete_event(calendar_id, second.id, token)

      {seen, expanded_cp} =
        poll_for(
          "event_cancelled_occurrence",
          expanded,
          expanded_cp,
          token,
          [second.id],
          &cancelled?/1
        )

      assert_cancelled_occurrence(seen, master_id, second)

      {seen, unexpanded_cp} =
        poll_for(
          "event_cancelled_occurrence_unexpanded",
          unexpanded,
          unexpanded_cp,
          token,
          [second.id],
          &cancelled?/1
        )

      assert_cancelled_occurrence(seen, master_id, second)

      # The cancelled series: the master on the unexpanded chain, the
      # remaining occurrences on the expanded one.
      LiveCalendar.skip_recording()
      assert {:ok, %{deleted?: true}} = delete_event(calendar_id, master_id, token)

      {seen, _cp} =
        poll_for(
          "event_cancelled_series_unexpanded",
          unexpanded,
          unexpanded_cp,
          token,
          [master_id],
          &cancelled?/1
        )

      master = cancelled_signal!(seen, master_id)
      assert master.event.recurring_event_id == nil
      assert master.event.original_start == nil

      {seen, _cp} =
        poll_for(
          "event_cancelled_series",
          expanded,
          expanded_cp,
          token,
          [first.id, third.id],
          &cancelled?/1
        )

      assert_cancelled_occurrence(seen, master_id, first)
      assert_cancelled_occurrence(seen, master_id, third)
    end
  end

  defp assert_cancelled_occurrence(seen, master_id, %{id: id, original_start: original_start}) do
    signal = cancelled_signal!(seen, id)
    assert signal.event.recurring_event_id == master_id
    assert DateTime.compare(instant(signal.event.original_start), instant(original_start)) == :eq
  end

  defp cancelled_signal!(seen, event_id) do
    assert %{status: "cancelled"} =
             signal = Enum.find(seen, &(&1.event_id == event_id and cancelled?(&1)))

    signal
  end

  # Polls from `checkpoint` until every event in `event_ids` has a signal
  # that satisfies `done?`, always continuing from the checkpoint the previous
  # poll returned. Returns the signals for `event_ids` across all polls and
  # the last checkpoint. Each attempt records under `name` again, so the
  # final poll is the one in `name.json`.
  defp poll_for(name, config, checkpoint, token, event_ids, done?, attempt \\ 1, seen \\ []) do
    LiveCalendar.record(name)

    assert {:ok, %{signals: signals, checkpoint: next}} =
             LiveCalendar.poll(config, checkpoint, token)

    assert is_binary(next) and next != ""
    seen = seen ++ Enum.filter(signals, &(&1.event_id in event_ids))
    done = Enum.all?(event_ids, fn id -> Enum.any?(seen, &(&1.event_id == id and done?.(&1))) end)

    if done or attempt >= @poll_attempts do
      {seen, next}
    else
      Process.sleep(@poll_pause_ms)
      poll_for(name, config, next, token, event_ids, done?, attempt + 1, seen)
    end
  end

  defp cancelled?(signal), do: signal.change_type == "cancelled"

  defp delete_event(calendar_id, event_id, token) do
    Client.delete_event(
      %{calendar_id: calendar_id, event_id: event_id, send_updates: "none"},
      token
    )
  end

  defp instant(timestamp) do
    {:ok, datetime, _offset} = DateTime.from_iso8601(timestamp)
    datetime
  end
end
