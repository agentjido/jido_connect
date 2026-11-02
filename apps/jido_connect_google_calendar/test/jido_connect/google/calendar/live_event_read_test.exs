defmodule Jido.Connect.Google.Calendar.LiveEventReadTest do
  @moduledoc """
  Live checks of the Calendar event reads against the prepared events of the
  Google Workspace test account.

      mix test --only live_smoke

  The seed scripts of the test account create the events these tests expect;
  see `docs/live_smoke_tests.md` for the variables and the recording mode.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect.Google.Calendar.TestSupport.LiveCalendar

  # A week of prepared events plus all six weekly occurrences, clear of the
  # Meet poll event on 2026-11-02. Results use the Berlin offset.
  @window %{
    time_min: "2026-11-09T00:00:00+01:00",
    time_max: "2026-12-15T00:00:00+01:00",
    time_zone: "Europe/Berlin"
  }
  @page_size 5
  # The window holds about a dozen events, three pages; a page token that
  # never ends stops here instead of calling, and recording, without bound.
  @max_pages 10

  @prepared_events [
    %{
      summary: "jcl-live timed Berlin",
      start: "2026-11-09T09:00:00+01:00",
      end: "2026-11-09T10:00:00+01:00",
      start_time_zone: "Europe/Berlin",
      end_time_zone: "Europe/Berlin",
      all_day?: false
    },
    %{
      summary: "jcl-live timed New York",
      start: "2026-11-09T20:00:00+01:00",
      end: "2026-11-09T20:30:00+01:00",
      start_time_zone: "America/New_York",
      end_time_zone: "America/New_York",
      all_day?: false
    },
    %{
      summary: "jcl-live timed Kolkata",
      start: "2026-11-10T07:00:00+01:00",
      end: "2026-11-10T07:45:00+01:00",
      start_time_zone: "Asia/Kolkata",
      end_time_zone: "Asia/Kolkata",
      all_day?: false
    },
    %{
      summary: "jcl-live across midnight",
      start: "2026-11-10T23:30:00+01:00",
      end: "2026-11-11T00:30:00+01:00",
      start_time_zone: "Europe/Berlin",
      end_time_zone: "Europe/Berlin",
      all_day?: false
    },
    %{
      summary: "jcl-live all-day",
      start: "2026-11-11",
      end: "2026-11-12",
      start_time_zone: nil,
      end_time_zone: nil,
      all_day?: true
    },
    %{
      summary: "jcl-live multi-day",
      start: "2026-11-12",
      end: "2026-11-15",
      start_time_zone: nil,
      end_time_zone: nil,
      all_day?: true
    }
  ]

  # FREQ=WEEKLY;COUNT=6;BYDAY=MO from 2026-11-09 08:00 Berlin; the second
  # occurrence is moved to 09:00.
  @weekly_summary "jcl-live weekly"
  @weekly_occurrences [
    {"2026-11-09T08:00:00+01:00", "2026-11-09T08:30:00+01:00", "2026-11-09T08:00:00+01:00"},
    {"2026-11-16T09:00:00+01:00", "2026-11-16T09:30:00+01:00", "2026-11-16T08:00:00+01:00"},
    {"2026-11-23T08:00:00+01:00", "2026-11-23T08:30:00+01:00", "2026-11-23T08:00:00+01:00"},
    {"2026-11-30T08:00:00+01:00", "2026-11-30T08:30:00+01:00", "2026-11-30T08:00:00+01:00"},
    {"2026-12-07T08:00:00+01:00", "2026-12-07T08:30:00+01:00", "2026-12-07T08:00:00+01:00"},
    {"2026-12-14T08:00:00+01:00", "2026-12-14T08:30:00+01:00", "2026-12-14T08:00:00+01:00"}
  ]

  describe "google.calendar.event.list" do
    @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_CALENDAR_ID"])
    test "reads timed, all-day and recurring events of a period across pages", %{env: env} do
      LiveCalendar.record("event_list")

      input =
        Map.merge(@window, %{
          calendar_id: env["GOOGLE_CALENDAR_ID"],
          page_size: @page_size,
          order_by: "startTime"
        })

      pages = list_pages(input, env["GOOGLE_ACCESS_TOKEN"])
      events = Enum.flat_map(pages, & &1.events)

      assert length(pages) >= 2
      assert Enum.all?(pages, &(length(&1.events) <= @page_size))

      for expected <- @prepared_events do
        assert [event] = Enum.filter(events, &(&1.summary == expected.summary))
        assert Map.take(event, Map.keys(expected)) == expected
      end

      weekly = Enum.filter(events, &(&1.summary == @weekly_summary))

      assert [master_id] = weekly |> Enum.map(& &1.recurring_event_id) |> Enum.uniq()
      assert is_binary(master_id)

      assert Enum.map(weekly, &{&1.start, &1.end, &1.original_start}) == @weekly_occurrences

      assert Enum.all?(weekly, &(&1.start_time_zone == "Europe/Berlin"))
      assert Enum.all?(weekly, &(&1.end_time_zone == "Europe/Berlin"))
    end
  end

  # The prepared meeting: its description is MEETING_DESCRIPTION of the seed
  # script, its attendees are the test user and GOOGLE_SEED_ATTENDEES, and its
  # attachments and Meet conference were created with it.
  @description_bytes 963
  @description_sha256 "beb1162d76d851842e2818b68a9f04cc225f9a0775cfd2247faf12bb75e866dd"

  # Titles and MIME types come from the seed script; the Drive and Meet IDs
  # change with every reseed and come from the environment.
  @agenda_title "jcl-live agenda"
  @agenda_mime_type "application/vnd.google-apps.document"
  @handout_title "jcl-live handout.txt"
  @handout_mime_type "text/plain"
  # The seed script appends this query to the handout link; Google keeps the escape.
  @handout_query_suffix "&jcl=a%20b"
  @attachment_keys ["fileId", "fileUrl", "title", "mimeType"]

  describe "google.calendar.event.get on the prepared meeting" do
    @tag env!([
           "GOOGLE_ACCESS_TOKEN",
           "GOOGLE_CALENDAR_ID",
           "GOOGLE_CALENDAR_EVENT_ID",
           "GOOGLE_TEST_USER",
           "GOOGLE_SEED_ATTENDEES"
         ])
    test "reads description, organizer and attendees under the read-only event scope", %{
      env: env
    } do
      event = get_meeting!(env)
      test_user = String.downcase(env["GOOGLE_TEST_USER"])

      assert event.event_id == env["GOOGLE_CALENDAR_EVENT_ID"]
      assert byte_size(event.description) == @description_bytes
      assert sha256(event.description) == @description_sha256

      assert String.downcase(event.organizer["email"]) == test_user
      assert event.organizer["self"] == true

      assert event.attendees_omitted? == false
      assert attendee_emails(event) == expected_attendees(env)
    end

    @tag env!([
           "GOOGLE_ACCESS_TOKEN",
           "GOOGLE_CALENDAR_ID",
           "GOOGLE_CALENDAR_EVENT_ID",
           "GOOGLE_CALENDAR_AGENDA_FILE_ID",
           "GOOGLE_CALENDAR_HANDOUT_URL",
           "GOOGLE_CALENDAR_CONFERENCE_ID"
         ])
    test "reads attachment and conference references without fetching them", %{env: env} do
      event = get_meeting!(env)
      agenda_id = env["GOOGLE_CALENDAR_AGENDA_FILE_ID"]
      handout_url = env["GOOGLE_CALENDAR_HANDOUT_URL"]
      conference_id = env["GOOGLE_CALENDAR_CONFERENCE_ID"]

      assert [agenda] = Enum.filter(event.attachments, &(&1["title"] == @agenda_title))

      assert Map.take(agenda, @attachment_keys) == %{
               "fileId" => agenda_id,
               "fileUrl" => "https://docs.google.com/document/d/#{agenda_id}/edit?usp=drivesdk",
               "title" => @agenda_title,
               "mimeType" => @agenda_mime_type
             }

      assert [handout] = Enum.filter(event.attachments, &(&1["title"] == @handout_title))

      assert Map.take(handout, @attachment_keys) == %{
               "fileUrl" => handout_url,
               "title" => @handout_title,
               "mimeType" => @handout_mime_type
             }

      assert String.ends_with?(handout["fileUrl"], @handout_query_suffix)

      assert event.conference_data["conferenceId"] == conference_id
      assert event.hangout_link == "https://meet.google.com/" <> conference_id
    end
  end

  defp get_meeting!(env) do
    LiveCalendar.record("event_get")

    assert {:ok, %{event: event}} =
             LiveCalendar.invoke(
               "google.calendar.event.get",
               %{
                 calendar_id: env["GOOGLE_CALENDAR_ID"],
                 event_id: env["GOOGLE_CALENDAR_EVENT_ID"]
               },
               env["GOOGLE_ACCESS_TOKEN"],
               [LiveCalendar.events_readonly_scope()]
             )

    event
  end

  defp attendee_emails(event) do
    event.attendees
    |> Enum.map(&String.downcase(&1.email))
    |> Enum.sort()
  end

  # The seed script invites the test user and every GOOGLE_SEED_ATTENDEES address.
  defp expected_attendees(env) do
    env["GOOGLE_SEED_ATTENDEES"]
    |> String.split(",", trim: true)
    |> Enum.concat([env["GOOGLE_TEST_USER"]])
    |> Enum.map(&(&1 |> String.trim() |> String.downcase()))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp sha256(text), do: :sha256 |> :crypto.hash(text) |> Base.encode16(case: :lower)

  # Follows next_page_token through the action until the last page.
  defp list_pages(input, access_token, pages \\ []) do
    assert length(pages) < @max_pages, "pagination did not end after #{@max_pages} pages"

    assert {:ok, page} =
             LiveCalendar.invoke(
               "google.calendar.event.list",
               input,
               access_token,
               [LiveCalendar.events_readonly_scope()]
             )

    pages = pages ++ [page]

    case Map.get(page, :next_page_token) do
      nil -> pages
      token -> list_pages(Map.put(input, :page_token, token), access_token, pages)
    end
  end
end
