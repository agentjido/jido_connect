defmodule Jido.Connect.Google.Calendar.LiveEventAttendeesTest do
  @moduledoc """
  Live checks of attendee data in Calendar event writes, reads and change
  polls against the Google Workspace test account.

      GOOGLE_LIVE_DESTRUCTIVE=true mix test --only live_smoke

  Each test creates its own event in March 2027 with a per-run event ID. The
  only real attendee is the test user; every other attendee has an address
  under the reserved domain `example.com`, and no notifications are sent.
  The events are deleted at the end and on exit; the deletes stay out of the
  recordings.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect.Google.Calendar.Client
  alias Jido.Connect.Google.Calendar.TestSupport.LiveCalendar

  # The change poll retries for about 20 s; see LiveCalendar.poll_since/6.
  @moduletag timeout: 300_000

  # The test user plus 50 guests, one more than the 50 attendees that the
  # read tests of event descriptions and participants ask for.
  @guest_count 50

  describe "google.calendar.event.create and google.calendar.event.get" do
    @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_CALENDAR_ID", "GOOGLE_TEST_USER"])
    @tag write!(:google)
    test "store 51 attendees, read them back in the same order and mark them omitted when capped",
         %{env: env} do
      %{
        "GOOGLE_ACCESS_TOKEN" => token,
        "GOOGLE_CALENDAR_ID" => calendar_id,
        "GOOGLE_TEST_USER" => test_user
      } = env

      run = LiveCalendar.run_id()
      event_id = "jclr1" <> run
      on_exit(fn -> LiveCalendar.delete_leftover(calendar_id, event_id, token) end)

      attendees = [%{email: test_user} | guests(run)]

      LiveCalendar.record("event_create_attendees")

      assert {:ok, %{event: created}} =
               LiveCalendar.invoke(
                 "google.calendar.event.create",
                 %{
                   calendar_id: calendar_id,
                   event_id: event_id,
                   summary: "jcl-live attendees #{run}",
                   description: "jcl-live attendee list #{run}",
                   location: "jcl-live room",
                   start: "2027-03-01T10:00:00+01:00",
                   end: "2027-03-01T11:00:00+01:00",
                   time_zone: "Europe/Berlin",
                   attendees: attendees,
                   send_updates: "none"
                 },
                 token,
                 [LiveCalendar.events_scope()]
               )

      # Google stores attendees in an order of its own, not in the order sent.
      assert Enum.sort(emails(created.attendees)) == Enum.sort(emails(attendees))

      LiveCalendar.record("event_get_attendees")
      event = get!(token, calendar_id, event_id, %{})

      assert length(event.attendees) == @guest_count + 1
      assert emails(event.attendees) == emails(created.attendees)
      assert event.attendees_omitted? == false
      assert [%{organizer?: true}] = Enum.filter(event.attendees, & &1.self?)

      LiveCalendar.record("event_get_attendees_omitted")
      capped = get!(token, calendar_id, event_id, %{max_attendees: 1})

      assert capped.attendees_omitted? == true
      assert length(capped.attendees) <= 1

      LiveCalendar.skip_recording()
      assert {:ok, %{deleted?: true}} = delete_event(calendar_id, event_id, token)
    end
  end

  describe "google.calendar.event.changed" do
    @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_CALENDAR_ID", "GOOGLE_TEST_USER"])
    @tag write!(:google)
    test "reports a confirmed event the test user declined as updated", %{env: env} do
      %{
        "GOOGLE_ACCESS_TOKEN" => token,
        "GOOGLE_CALENDAR_ID" => calendar_id,
        "GOOGLE_TEST_USER" => test_user
      } = env

      run = LiveCalendar.run_id()
      event_id = "jclr2" <> run
      on_exit(fn -> LiveCalendar.delete_leftover(calendar_id, event_id, token) end)
      config = %{calendar_id: calendar_id}

      # The full sync is recorded by the change poll checks; only the
      # incremental poll after the write is recorded here.
      LiveCalendar.skip_recording()
      assert {:ok, %{signals: [], checkpoint: checkpoint}} = LiveCalendar.poll(config, nil, token)

      assert {:ok, _event} =
               Client.create_event(
                 %{
                   calendar_id: calendar_id,
                   event_id: event_id,
                   summary: "jcl-live declined #{run}",
                   start: "2027-03-02T10:00:00+01:00",
                   end: "2027-03-02T10:30:00+01:00",
                   time_zone: "Europe/Berlin",
                   attendees: [
                     %{email: test_user, response_status: "declined"},
                     %{email: "jcl-guest-#{run}@example.com"}
                   ],
                   send_updates: "none"
                 },
                 token
               )

      assert {:ok, %{signals: signals}} =
               LiveCalendar.poll_since(
                 "event_changed_declined",
                 config,
                 checkpoint,
                 token,
                 &declined_signal(&1, event_id)
               )

      assert %{status: "confirmed", change_type: "updated", event: event} =
               declined_signal(signals, event_id)

      assert [%{response_status: "declined"}] = Enum.filter(event.attendees, & &1.self?)
      LiveCalendar.assert_recorded_poll("event_changed_declined", [event_id], 1)

      LiveCalendar.skip_recording()
      assert {:ok, %{deleted?: true}} = delete_event(calendar_id, event_id, token)
    end
  end

  # Every tenth guest carries the optional attendee fields. The guest after it
  # sends `optional: false` and `additional_guests: 0`, which Google leaves out
  # of its answers.
  defp guests(run) do
    for n <- 1..@guest_count do
      number = n |> Integer.to_string() |> String.pad_leading(2, "0")
      guest = %{email: "jcl-guest-#{number}-#{run}@example.com"}

      cond do
        rem(n, 10) == 0 ->
          Map.merge(guest, %{
            display_name: "Guest #{number}",
            optional: true,
            comment: "jcl-live comment #{number}",
            additional_guests: 2
          })

        rem(n, 10) == 1 ->
          Map.merge(guest, %{optional: false, additional_guests: 0})

        true ->
          guest
      end
    end
  end

  defp declined_signal(signals, event_id) do
    Enum.find(signals, fn signal ->
      signal.event_id == event_id and
        Enum.any?(signal.event.attendees, &(&1.self? and &1.response_status == "declined"))
    end)
  end

  defp get!(token, calendar_id, event_id, input) do
    assert {:ok, %{event: event}} =
             LiveCalendar.invoke(
               "google.calendar.event.get",
               Map.merge(%{calendar_id: calendar_id, event_id: event_id}, input),
               token,
               [LiveCalendar.events_readonly_scope()]
             )

    assert event.event_id == event_id
    event
  end

  defp emails(attendees), do: Enum.map(attendees, &String.downcase(&1.email))

  defp delete_event(calendar_id, event_id, token) do
    Client.delete_event(
      %{calendar_id: calendar_id, event_id: event_id, send_updates: "none"},
      token
    )
  end
end
