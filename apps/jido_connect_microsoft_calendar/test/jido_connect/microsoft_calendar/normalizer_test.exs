defmodule Jido.Connect.MicrosoftCalendar.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.MicrosoftCalendar.{
    Attendee,
    AvailabilityResult,
    Calendar,
    CalendarGroup,
    Event,
    FreeBusySlot,
    Location,
    Normalizer,
    Recurrence
  }

  # ── Fixture helpers ───────────────────────────────────────────────────

  defp fixture!(name) do
    __DIR__
    |> Path.join("../../fixtures/calendar/#{name}.json")
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end

  defp calendar_default, do: fixture!("calendar_default")
  defp calendar_shared, do: fixture!("calendar_shared")
  defp calendars_list, do: fixture!("calendars_list")
  defp calendar_group, do: fixture!("calendar_group")
  defp calendar_groups_list, do: fixture!("calendar_groups_list")
  defp event_detail, do: fixture!("event_detail")
  defp events_list, do: fixture!("events_list")
  defp events_empty, do: fixture!("events_empty")
  defp availability_results, do: fixture!("availability_results")

  # ── Calendar ──────────────────────────────────────────────────────────

  describe "calendar/1" do
    test "normalizes a default Microsoft Graph calendar payload" do
      assert {:ok, %Calendar{} = cal} = Normalizer.calendar(calendar_default())

      assert cal.calendar_id == "AAMkAGI2TG93AAA="
      assert cal.name == "Calendar"
      assert cal.color == "auto"
      assert cal.is_default_calendar == true
      assert cal.is_shared == false
      assert cal.is_tallying_replies == false
      assert cal.can_edit == true
      assert cal.can_share == true
      assert cal.can_view_private_items == true
      assert cal.owner == %{name: "Megan Bowen", address: "meganb@contoso.com"}
    end

    test "normalizes a shared calendar with hex color" do
      assert {:ok, %Calendar{} = cal} = Normalizer.calendar(calendar_shared())

      assert cal.calendar_id == "AAMkAGI2TG93BBB="
      assert cal.name == "Team Events"
      assert cal.color == "blue"
      assert cal.hex_color == "#0000FF"
      assert cal.is_default_calendar == false
      assert cal.is_shared == true
      assert cal.is_tallying_replies == true
      assert cal.can_share == false
      assert cal.owner == %{name: "All Users", address: "allusers@contoso.com"}
      assert cal.calendar_group_id == "AQMkAGI2GRP1AAA="
    end

    test "normalizes a calendar with minimal fields" do
      assert {:ok, %Calendar{} = cal} =
               Normalizer.calendar(%{
                 "id" => "CAL-123",
                 "name" => "My Calendar"
               })

      assert cal.calendar_id == "CAL-123"
      assert cal.name == "My Calendar"
      assert cal.is_default_calendar == nil
      assert cal.owner == nil
    end

    test "rejects malformed calendar payloads" do
      assert {:error, :invalid_calendar_payload} = Normalizer.calendar(:bad)
      assert {:error, :invalid_calendar_payload} = Normalizer.calendar(nil)
    end
  end

  # ── Calendar Group ────────────────────────────────────────────────────

  describe "calendar_group/1" do
    test "normalizes a Microsoft Graph calendarGroup payload" do
      assert {:ok, %CalendarGroup{} = group} = Normalizer.calendar_group(calendar_group())

      assert group.group_id == "AQMkAGI2GRP1AAA="
      assert group.name == "Work Calendars"
      assert group.class_id == "AQMkAGI2GRP1CLS="
      assert group.change_key =~ "CQAAABY"
      assert group.calendar_count == 2
    end

    test "normalizes a calendar group with minimal fields" do
      assert {:ok, %CalendarGroup{} = group} =
               Normalizer.calendar_group(%{"id" => "GRP-123"})

      assert group.group_id == "GRP-123"
      assert group.name == nil
    end

    test "rejects malformed calendar group payloads" do
      assert {:error, :invalid_calendar_group_payload} = Normalizer.calendar_group(:bad)
      assert {:error, :invalid_calendar_group_payload} = Normalizer.calendar_group(nil)
    end
  end

  # ── Event ─────────────────────────────────────────────────────────────

  describe "event/1" do
    test "normalizes a full event payload from fixture" do
      assert {:ok, %Event{} = ev} = Normalizer.event(event_detail())

      assert ev.event_id == "AAMkEV1AAA="
      assert ev.i_cal_uid =~ "040000008200E000"
      assert ev.subject == "Quarterly planning sync"
      assert ev.body_preview =~ "quarterly planning"
      assert ev.is_all_day == false
      assert ev.is_cancelled == false
      assert ev.is_organizer == true
      assert ev.sensitivity == "normal"
      assert ev.show_as == "busy"
      assert ev.has_attachments == false
      assert ev.online_meeting_url =~ "teams.microsoft.com"
    end

    test "normalizes start and end date-time fields" do
      assert {:ok, %Event{} = ev} = Normalizer.event(event_detail())

      assert ev.start.date_time == "2026-06-15T10:00:00"
      assert ev.start.time_zone == "Pacific Standard Time"
      assert ev.end.date_time == "2026-06-15T11:30:00"
      assert ev.end.time_zone == "Pacific Standard Time"
    end

    test "normalizes organizer" do
      assert {:ok, %Event{} = ev} = Normalizer.event(event_detail())

      assert ev.organizer.name == "Megan Bowen"
      assert ev.organizer.address == "meganb@contoso.com"
    end

    test "normalizes attendees with type and status" do
      assert {:ok, %Event{} = ev} = Normalizer.event(event_detail())

      assert length(ev.attendees) == 2

      [first, second] = ev.attendees

      assert first.name == "Brian Johnson"
      assert first.address == "brianj@contoso.com"
      assert first.type == "required"
      assert first.status.response == "accepted"

      assert second.name == "All Users"
      assert second.address == "allusers@contoso.com"
      assert second.type == "optional"
    end

    test "normalizes location with address and coordinates" do
      assert {:ok, %Event{} = ev} = Normalizer.event(event_detail())

      assert ev.location.display_name == "Conference Room 1"
      assert ev.location.location_uri == "https://contoso.com/rooms/cr1"
      assert ev.location.location_type == "conferenceRoom"
      assert ev.location.address["city"] == "Redmond"
      assert ev.location.coordinates["latitude"] == 47.6405
    end

    test "normalizes locations list" do
      assert {:ok, %Event{} = ev} = Normalizer.event(event_detail())

      assert length(ev.locations) == 1
      assert hd(ev.locations).display_name == "Conference Room 1"
    end

    test "normalizes recurrence pattern and range" do
      assert {:ok, %Event{} = ev} = Normalizer.event(event_detail())

      assert ev.recurrence.pattern.type == "weekly"
      assert ev.recurrence.pattern.interval == 2
      assert ev.recurrence.pattern.days_of_week == ["monday"]
      assert ev.recurrence.range.type == "endDate"
      assert ev.recurrence.range.start_date == "2026-06-15"
      assert ev.recurrence.range.end_date == "2026-12-31"
    end

    test "normalizes online meeting metadata" do
      assert {:ok, %Event{} = ev} = Normalizer.event(event_detail())

      assert ev.online_meeting.join_url =~ "teams.microsoft.com"
      assert ev.online_meeting.conference_id == "conf123"
      assert ev.online_meeting.toll_free_number == "+1-800-555-0100"
      assert ev.online_meeting.toll_number == "+1-425-555-0100"
    end

    test "summarizes body without exposing raw content" do
      assert {:ok, %Event{} = ev} = Normalizer.event(event_detail())

      assert ev.body_summary.content_type == "html"
      assert is_integer(ev.body_summary.body_size)
      refute Map.has_key?(ev.body_summary, :content)
    end

    test "handles event with no attendees or location gracefully" do
      assert {:ok, %Event{} = ev} =
               Normalizer.event(%{
                 "id" => "evt-empty",
                 "attendees" => nil,
                 "body" => nil,
                 "location" => nil,
                 "locations" => nil,
                 "recurrence" => nil
               })

      assert ev.attendees == []
      assert ev.body_summary == %{}
      assert ev.location == nil
      assert ev.locations == []
      assert ev.recurrence == nil
    end

    test "rejects malformed event payloads" do
      assert {:error, :invalid_event_payload} = Normalizer.event(:bad)
      assert {:error, :invalid_event_payload} = Normalizer.event("string")
    end
  end

  # ── Attendee ──────────────────────────────────────────────────────────

  describe "attendee/1" do
    test "normalizes a Microsoft Graph attendee object" do
      assert {:ok, %Attendee{} = att} =
               Normalizer.attendee(%{
                 "type" => "required",
                 "status" => %{
                   "response" => "accepted",
                   "time" => "2026-05-19T14:00:00Z"
                 },
                 "emailAddress" => %{
                   "name" => "Brian Johnson",
                   "address" => "brianj@contoso.com"
                 }
               })

      assert att.name == "Brian Johnson"
      assert att.address == "brianj@contoso.com"
      assert att.type == "required"
      assert att.status.response == "accepted"
      assert att.status.time == "2026-05-19T14:00:00Z"
    end

    test "handles attendee with missing emailAddress" do
      assert {:ok, %Attendee{} = att} = Normalizer.attendee(%{"emailAddress" => nil})

      assert att.name == nil
      assert att.address == nil
    end

    test "rejects malformed attendee payloads" do
      assert {:error, :invalid_attendee_payload} = Normalizer.attendee(:bad)
      assert {:error, :invalid_attendee_payload} = Normalizer.attendee(nil)
    end
  end

  # ── Location ──────────────────────────────────────────────────────────

  describe "location/1" do
    test "normalizes a Microsoft Graph location object" do
      assert {:ok, %Location{} = loc} =
               Normalizer.location(%{
                 "displayName" => "Conference Room 1",
                 "locationUri" => "https://contoso.com/rooms/cr1",
                 "locationType" => "conferenceRoom",
                 "address" => %{"city" => "Redmond"},
                 "coordinates" => %{"latitude" => 47.64}
               })

      assert loc.display_name == "Conference Room 1"
      assert loc.location_uri == "https://contoso.com/rooms/cr1"
      assert loc.location_type == "conferenceRoom"
      assert loc.address["city"] == "Redmond"
      assert loc.coordinates["latitude"] == 47.64
    end

    test "handles location with minimal fields" do
      assert {:ok, %Location{} = loc} =
               Normalizer.location(%{"displayName" => "Online"})

      assert loc.display_name == "Online"
      assert loc.address == nil
    end

    test "rejects malformed location payloads" do
      assert {:error, :invalid_location_payload} = Normalizer.location(:bad)
      assert {:error, :invalid_location_payload} = Normalizer.location(nil)
    end
  end

  # ── Recurrence ────────────────────────────────────────────────────────

  describe "recurrence/1" do
    test "normalizes a Microsoft Graph patternedRecurrence object" do
      assert {:ok, %Recurrence{} = rec} =
               Normalizer.recurrence(%{
                 "pattern" => %{
                   "type" => "daily",
                   "interval" => 3
                 },
                 "range" => %{
                   "type" => "noEnd",
                   "startDate" => "2026-06-01"
                 }
               })

      assert rec.pattern.type == "daily"
      assert rec.pattern.interval == 3
      assert rec.range.type == "noEnd"
      assert rec.range.start_date == "2026-06-01"
    end

    test "handles recurrence with missing pattern" do
      assert {:ok, %Recurrence{} = rec} =
               Normalizer.recurrence(%{
                 "range" => %{"type" => "numbered", "startDate" => "2026-06-01"}
               })

      assert rec.pattern == nil
      assert rec.range.type == "numbered"
    end

    test "rejects malformed recurrence payloads" do
      assert {:error, :invalid_recurrence_payload} = Normalizer.recurrence(:bad)
      assert {:error, :invalid_recurrence_payload} = Normalizer.recurrence(nil)
    end
  end

  # ── FreeBusy Slot ─────────────────────────────────────────────────────

  describe "freebusy_slot/1" do
    test "normalizes a Microsoft Graph scheduleItem" do
      assert {:ok, %FreeBusySlot{} = slot} =
               Normalizer.freebusy_slot(%{
                 "start" => %{
                   "dateTime" => "2026-06-15T09:00:00",
                   "timeZone" => "UTC"
                 },
                 "end" => %{
                   "dateTime" => "2026-06-15T10:00:00",
                   "timeZone" => "UTC"
                 },
                 "status" => "busy"
               })

      assert slot.start.date_time == "2026-06-15T09:00:00"
      assert slot.end.date_time == "2026-06-15T10:00:00"
      assert slot.status == "busy"
    end

    test "handles freebusy slot with minimal fields" do
      assert {:ok, %FreeBusySlot{} = slot} = Normalizer.freebusy_slot(%{})

      assert slot.start == nil
      assert slot.status == nil
    end

    test "rejects malformed freebusy slot payloads" do
      assert {:error, :invalid_freebusy_slot_payload} = Normalizer.freebusy_slot(:bad)
      assert {:error, :invalid_freebusy_slot_payload} = Normalizer.freebusy_slot(nil)
    end
  end

  # ── Availability Result ───────────────────────────────────────────────

  describe "availability_result/1" do
    test "normalizes a Microsoft Graph scheduleInformation with slots" do
      results = availability_results()
      [first, _second] = results["value"]

      assert {:ok, %AvailabilityResult{} = ar} = Normalizer.availability_result(first)

      assert ar.schedule_id == "meganb@contoso.com"
      assert ar.availability_view == "110022001100"
      assert length(ar.slots) == 2
      assert ar.error == nil

      [s1, s2] = ar.slots
      assert s1.status == "busy"
      assert s1.start.date_time == "2026-06-15T09:00:00"
      assert s2.status == "tentative"
    end

    test "normalizes an availability result with error" do
      results = availability_results()
      [_first, second] = results["value"]

      assert {:ok, %AvailabilityResult{} = ar} = Normalizer.availability_result(second)

      assert ar.schedule_id == "brianj@contoso.com"
      assert length(ar.slots) == 1
      assert ar.error["responseCode"] == "ErrorFreeBusyAccessDenied"
    end

    test "rejects malformed availability result payloads" do
      assert {:error, :invalid_availability_result_payload} =
               Normalizer.availability_result(:bad)

      assert {:error, :invalid_availability_result_payload} =
               Normalizer.availability_result(nil)
    end
  end

  # ── Paging envelope ───────────────────────────────────────────────────

  describe "page/2" do
    test "extracts normalized calendars from a Graph list envelope" do
      envelope = calendars_list()

      assert {:ok, %{items: calendars, next_link: next}} =
               Normalizer.page(envelope, &Normalizer.calendar/1)

      assert length(calendars) == 2
      assert [%Calendar{name: "Calendar"} | _] = calendars
      assert next =~ "$skip=10"
    end

    test "extracts normalized events from a Graph list envelope" do
      envelope = events_list()

      assert {:ok, %{items: events, next_link: next}} =
               Normalizer.page(envelope, &Normalizer.event/1)

      assert length(events) == 2
      assert [%Event{subject: "Quarterly planning sync"} | _] = events
      assert next =~ "$skip=25"
    end

    test "extracts normalized calendar groups from a Graph list envelope" do
      envelope = calendar_groups_list()

      assert {:ok, %{items: groups, next_link: nil}} =
               Normalizer.page(envelope, &Normalizer.calendar_group/1)

      assert length(groups) == 2
      assert [%CalendarGroup{name: "Work Calendars"} | _] = groups
    end

    test "handles empty value array" do
      envelope = events_empty()

      assert {:ok, %{items: [], next_link: nil}} =
               Normalizer.page(envelope, &Normalizer.event/1)
    end

    test "returns error for malformed envelope" do
      assert {:error, :invalid_page_envelope} = Normalizer.page(:bad, &Normalizer.calendar/1)
      assert {:error, :invalid_page_envelope} = Normalizer.page(nil, &Normalizer.calendar/1)
    end

    test "propagates normalizer errors" do
      envelope = %{
        "value" => [%{"name" => "Missing ID"}]
      }

      assert {:error, _reason} = Normalizer.page(envelope, &Normalizer.calendar/1)
    end
  end

  # ── Batch helpers ─────────────────────────────────────────────────────

  describe "normalize_list/2" do
    test "normalizes multiple attendees" do
      payloads = [
        %{
          "emailAddress" => %{"name" => "User A", "address" => "a@contoso.com"},
          "type" => "required"
        },
        %{
          "emailAddress" => %{"name" => "User B", "address" => "b@contoso.com"},
          "type" => "optional"
        }
      ]

      assert {:ok, [%Attendee{} = a1, %Attendee{} = a2]} =
               Normalizer.normalize_list(payloads, &Normalizer.attendee/1)

      assert a1.name == "User A"
      assert a2.name == "User B"
    end

    test "returns error for invalid list" do
      assert {:error, :invalid_list_payloads} =
               Normalizer.normalize_list(:bad, &Normalizer.attendee/1)
    end
  end

  # ── Struct contracts ──────────────────────────────────────────────────

  describe "struct contracts" do
    test "Calendar struct exposes schema defaults and rejects invalid input" do
      cal = Calendar.new!(%{calendar_id: "id1"})
      assert cal.metadata == %{}
      assert {:error, _error} = Calendar.new(%{})
    end

    test "CalendarGroup struct exposes schema defaults and rejects invalid input" do
      group = CalendarGroup.new!(%{group_id: "grp1"})
      assert group.metadata == %{}
      assert {:error, _error} = CalendarGroup.new(%{})
    end

    test "Event struct exposes schema defaults and rejects invalid input" do
      ev = Event.new!(%{event_id: "evt1"})
      assert ev.body_summary == %{}
      assert ev.attendees == []
      assert ev.locations == []
      assert ev.metadata == %{}
      assert {:error, _error} = Event.new(%{})
    end

    test "Attendee struct accepts empty attributes" do
      assert {:ok, %Attendee{} = att} = Attendee.new(%{})
      assert att.metadata == %{}
    end

    test "Location struct accepts empty attributes" do
      assert {:ok, %Location{} = loc} = Location.new(%{})
      assert loc.metadata == %{}
    end

    test "Recurrence struct accepts empty attributes" do
      assert {:ok, %Recurrence{} = rec} = Recurrence.new(%{})
      assert rec.metadata == %{}
    end

    test "FreeBusySlot struct accepts empty attributes" do
      assert {:ok, %FreeBusySlot{} = slot} = FreeBusySlot.new(%{})
      assert slot.metadata == %{}
    end

    test "AvailabilityResult struct exposes schema defaults and accepts empty input" do
      assert {:ok, %AvailabilityResult{} = ar} = AvailabilityResult.new(%{})
      assert ar.slots == []
      assert ar.error == nil
      assert ar.metadata == %{}
    end
  end
end
