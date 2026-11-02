defmodule Jido.Connect.Google.Calendar.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Calendar.{
    AclRule,
    Attendee,
    Calendar,
    Channel,
    Event,
    FreeBusy,
    Normalizer
  }

  alias Jido.Connect.Google.TestSupport.ConnectorContracts
  alias Jido.Connect.TestSupport.LiveSmoke

  test "normalizes calendar-list entries" do
    assert {:ok, %Calendar{} = calendar} =
             Normalizer.calendar(%{
               "id" => "primary",
               "summary" => "Primary Calendar",
               "timeZone" => "America/Chicago",
               "accessRole" => "owner",
               "etag" => "\"calendar-etag\"",
               "kind" => "calendar#calendarListEntry",
               "backgroundColor" => "#2952a3",
               "foregroundColor" => "#ffffff",
               "primary" => true,
               "selected" => true,
               "conferenceProperties" => %{
                 "allowedConferenceSolutionTypes" => ["hangoutsMeet"]
               },
               "defaultReminders" => [%{"method" => "popup", "minutes" => 10}]
             })

    assert calendar.calendar_id == "primary"
    assert calendar.etag == "\"calendar-etag\""
    assert calendar.kind == "calendar#calendarListEntry"
    assert calendar.summary == "Primary Calendar"
    assert calendar.time_zone == "America/Chicago"
    assert calendar.access_role == "owner"
    assert calendar.primary?
    assert calendar.selected?

    assert calendar.conference_properties == %{
             "allowedConferenceSolutionTypes" => ["hangoutsMeet"]
           }

    assert calendar.default_reminders == [%{"method" => "popup", "minutes" => 10}]
  end

  test "normalizes ACL rules" do
    assert {:ok, %AclRule{} = acl_rule} =
             Normalizer.acl_rule(
               %{
                 "id" => "user:guest@example.com",
                 "etag" => "\"acl-etag\"",
                 "kind" => "calendar#aclRule",
                 "role" => "reader",
                 "scope" => %{
                   "type" => "user",
                   "value" => "guest@example.com"
                 }
               },
               calendar_id: "primary"
             )

    assert acl_rule.acl_rule_id == "user:guest@example.com"
    assert acl_rule.calendar_id == "primary"
    assert acl_rule.role == "reader"
    assert acl_rule.scope_type == "user"
    assert acl_rule.scope_value == "guest@example.com"
    assert acl_rule.etag == "\"acl-etag\""
    assert acl_rule.kind == "calendar#aclRule"
  end

  test "normalizes attendees" do
    assert {:ok, %Attendee{} = attendee} =
             Normalizer.attendee(%{
               "email" => "guest@example.com",
               "displayName" => "Guest",
               "responseStatus" => "accepted",
               "optional" => true,
               "additionalGuests" => 1
             })

    assert attendee.email == "guest@example.com"
    assert attendee.display_name == "Guest"
    assert attendee.response_status == "accepted"
    assert attendee.optional?
    assert attendee.additional_guests == 1
  end

  test "normalizes timed events with attendees" do
    assert {:ok, %Event{} = event} =
             Normalizer.event(
               %{
                 "id" => "event123",
                 "iCalUID" => "event123@example.com",
                 "status" => "confirmed",
                 "summary" => "Planning",
                 "description" => "Quarterly planning",
                 "location" => "Room 1",
                 "htmlLink" => "https://calendar.google.com/event?eid=event123",
                 "creator" => %{"email" => "owner@example.com"},
                 "organizer" => %{"email" => "owner@example.com"},
                 "start" => %{
                   "dateTime" => "2026-05-06T09:00:00-05:00",
                   "timeZone" => "America/Chicago"
                 },
                 "end" => %{
                   "dateTime" => "2026-05-06T10:00:00-05:00",
                   "timeZone" => "America/Chicago"
                 },
                 "attendees" => [
                   %{"email" => "guest@example.com", "responseStatus" => "needsAction"}
                 ],
                 "conferenceData" => %{"conferenceId" => "meet123"},
                 "reminders" => %{"useDefault" => true},
                 "transparency" => "opaque",
                 "visibility" => "default",
                 "eventType" => "default",
                 "created" => "2026-05-01T12:00:00Z",
                 "updated" => "2026-05-02T12:00:00Z",
                 "sequence" => 1
               },
               calendar_id: "primary"
             )

    assert event.event_id == "event123"
    assert event.calendar_id == "primary"
    assert event.start == "2026-05-06T09:00:00-05:00"
    assert event.end == "2026-05-06T10:00:00-05:00"
    assert event.start_time_zone == "America/Chicago"
    refute event.all_day?
    assert [%Attendee{email: "guest@example.com"}] = event.attendees
    assert event.conference_data == %{"conferenceId" => "meet123"}
  end

  test "normalizes all-day recurring event dates" do
    assert {:ok, %Event{} = event} =
             Normalizer.event(%{
               "id" => "event456",
               "status" => "confirmed",
               "start" => %{"date" => "2026-05-06"},
               "end" => %{"date" => "2026-05-07"},
               "recurrence" => ["RRULE:FREQ=WEEKLY;COUNT=2"],
               "recurringEventId" => "series123",
               "originalStartTime" => %{"date" => "2026-05-06"}
             })

    assert event.start == "2026-05-06"
    assert event.end == "2026-05-07"
    assert event.all_day?
    assert event.recurrence == ["RRULE:FREQ=WEEKLY;COUNT=2"]
    assert event.original_start == "2026-05-06"
  end

  describe "recorded event details" do
    test "keep a long description with Unicode and HTML byte for byte" do
      recorded = recorded("event_get")
      description = recorded["description"]

      assert byte_size(description) > 512
      assert String.length(description) < byte_size(description)
      assert description =~ "<b>"
      assert description =~ "&amp;"

      assert {:ok, %Event{} = event} = Normalizer.event(recorded, calendar_id: "primary")
      assert event.description == description
    end

    test "keep 51 attendees in the order Google returned them" do
      recorded = recorded("event_get_attendees")

      assert {:ok, %Event{} = event} = Normalizer.event(recorded, calendar_id: "primary")

      assert length(event.attendees) == 51

      assert Enum.map(event.attendees, & &1.email) ==
               Enum.map(recorded["attendees"], & &1["email"])

      assert event.attendees_omitted? == false
    end

    test "keep attendee details and explicit false flags" do
      recorded = recorded("event_get_attendees")
      [detailed | _others] = Enum.filter(recorded["attendees"], &Map.has_key?(&1, "comment"))

      # Derived: Google leaves false flags and zero extra guests out of its
      # answers, so one recorded guest gets them added explicitly.
      plain = Enum.find(recorded["attendees"], &(Map.keys(&1) == ["email", "responseStatus"]))

      explicit =
        Map.merge(plain, %{
          "optional" => false,
          "organizer" => false,
          "resource" => false,
          "self" => false,
          "additionalGuests" => 0
        })

      attendees = Enum.map(recorded["attendees"], &if(&1 == plain, do: explicit, else: &1))

      assert {:ok, %Event{} = event} =
               Normalizer.event(Map.put(recorded, "attendees", attendees), calendar_id: "primary")

      assert %Attendee{
               display_name: display_name,
               comment: comment,
               optional?: true,
               additional_guests: 2
             } = attendee!(event, detailed["email"])

      assert display_name == detailed["displayName"]
      assert comment == detailed["comment"]

      assert %Attendee{
               optional?: false,
               organizer?: false,
               resource?: false,
               self?: false,
               additional_guests: 0
             } = attendee!(event, explicit["email"])

      assert %Attendee{organizer?: true, self?: true} =
               Enum.find(event.attendees, & &1.self?)
    end

    test "mark a capped attendee list as omitted" do
      recorded = recorded("event_get_attendees_omitted")
      assert recorded["attendeesOmitted"] == true

      assert {:ok, %Event{} = event} = Normalizer.event(recorded, calendar_id: "primary")

      assert event.attendees_omitted? == true
      assert [%Attendee{self?: true}] = event.attendees
    end

    test "keep attachments as provider-keyed maps with their links unchanged" do
      recorded = recorded("event_get")

      assert {:ok, %Event{} = event} = Normalizer.event(recorded, calendar_id: "primary")
      assert event.attachments == recorded["attachments"]

      agenda = Enum.find(event.attachments, &(&1["title"] == "jcl-live agenda"))

      assert agenda |> Map.keys() |> Enum.sort() ==
               ["fileId", "fileUrl", "iconLink", "mimeType", "title"]

      assert agenda["mimeType"] == "application/vnd.google-apps.document"
      assert agenda["fileUrl"] =~ agenda["fileId"]

      handout = Enum.find(event.attachments, &(&1["title"] == "jcl-live handout.txt"))
      refute Map.has_key?(handout, "fileId")
      assert String.ends_with?(handout["fileUrl"], "?usp=drivesdk&jcl=a%20b")
    end

    test "keep the Meet link and conference data" do
      recorded = recorded("event_get")

      assert {:ok, %Event{} = event} = Normalizer.event(recorded, calendar_id: "primary")

      assert event.hangout_link == recorded["hangoutLink"]
      assert event.conference_data == recorded["conferenceData"]

      # The recording replaced each entry point URI with a placeholder,
      # because the `more` URI carries the dial-in PIN.
      assert Enum.map(event.conference_data["entryPoints"], & &1["uri"]) ==
               ["uri-1", "uri-2", "uri-3"]
    end

    test "keep the identity of an event without description, attachments or conference" do
      recorded = recorded("event_create_get")

      for field <- ~w(description attachments attendees conferenceData hangoutLink) do
        refute Map.has_key?(recorded, field)
      end

      assert {:ok, %Event{} = event} = Normalizer.event(recorded, calendar_id: "primary")

      assert event.event_id == recorded["id"]
      assert event.calendar_id == "primary"
      assert event.attachments == []
      assert event.attendees == []
      assert event.description == nil
      assert event.hangout_link == nil
      assert event.conference_data == nil
    end
  end

  test "returns errors instead of raising for malformed attendees" do
    assert {:error, _error} =
             Normalizer.event(%{
               "id" => "event789",
               "attendees" => [%{"displayName" => "Missing email"}]
             })
  end

  test "normalizes freebusy responses with flattened busy windows" do
    assert {:ok, %FreeBusy{} = free_busy} =
             Normalizer.free_busy(%{
               "timeMin" => "2026-05-06T00:00:00Z",
               "timeMax" => "2026-05-07T00:00:00Z",
               "calendars" => %{
                 "primary" => %{
                   "busy" => [
                     %{
                       "start" => "2026-05-06T09:00:00Z",
                       "end" => "2026-05-06T10:00:00Z"
                     }
                   ]
                 }
               },
               "groups" => %{}
             })

    assert free_busy.time_min == "2026-05-06T00:00:00Z"
    assert free_busy.time_max == "2026-05-07T00:00:00Z"

    assert free_busy.busy == [
             %{
               calendar_id: "primary",
               start: "2026-05-06T09:00:00Z",
               end: "2026-05-06T10:00:00Z"
             }
           ]
  end

  test "normalizes notification channels" do
    assert {:ok, %Channel{} = channel} =
             Normalizer.channel(%{
               "kind" => "api#channel",
               "id" => "event-channel",
               "resourceId" => "events-resource",
               "resourceUri" => "https://www.googleapis.com/calendar/v3/calendars/primary/events",
               "token" => "tenant=1",
               "expiration" => 1_779_000_000_000
             })

    assert channel.channel_id == "event-channel"
    assert channel.resource_id == "events-resource"

    assert channel.resource_uri ==
             "https://www.googleapis.com/calendar/v3/calendars/primary/events"

    assert channel.token == "tenant=1"
    assert channel.expiration == "1779000000000"
  end

  test "normalizes freebusy per-calendar and per-group errors" do
    assert {:ok, %FreeBusy{} = free_busy} =
             Normalizer.free_busy(%{
               "timeMin" => "2026-05-06T00:00:00Z",
               "timeMax" => "2026-05-07T00:00:00Z",
               "calendars" => %{
                 "missing@example.com" => %{
                   "errors" => [%{"domain" => "global", "reason" => "notFound"}],
                   "busy" => []
                 }
               },
               "groups" => %{
                 "team@example.com" => %{
                   "errors" => [%{"domain" => "global", "reason" => "groupTooBig"}],
                   "calendars" => []
                 }
               }
             })

    assert free_busy.errors == [
             %{
               target_type: :calendar,
               target_id: "missing@example.com",
               domain: "global",
               reason: "notFound"
             },
             %{
               target_type: :group,
               target_id: "team@example.com",
               domain: "global",
               reason: "groupTooBig"
             }
           ]
  end

  test "struct constructors expose schema defaults" do
    ConnectorContracts.assert_struct_defaults(Calendar, %{calendar_id: "primary"},
      selected?: false,
      hidden?: false,
      primary?: false,
      deleted?: false,
      conference_properties: %{},
      default_reminders: [],
      notification_settings: %{},
      metadata: %{}
    )

    assert {:error, _error} = Calendar.new(%{})

    ConnectorContracts.assert_struct_defaults(Attendee, %{email: "guest@example.com"},
      additional_guests: 0,
      optional?: false,
      organizer?: false,
      resource?: false,
      self?: false,
      metadata: %{}
    )

    assert {:error, _error} = Attendee.new(%{})

    ConnectorContracts.assert_struct_defaults(Event, %{event_id: "event123"},
      recurrence: [],
      attendees: [],
      all_day?: false,
      reminders: %{},
      attachments: [],
      extended_properties: %{},
      metadata: %{}
    )

    assert {:error, _error} = Event.new(%{})

    ConnectorContracts.assert_struct_defaults(Channel, %{channel_id: "event-channel"},
      params: %{},
      metadata: %{}
    )

    assert {:error, _error} = Channel.new(%{})

    ConnectorContracts.assert_struct_defaults(AclRule, %{acl_rule_id: "default"}, metadata: %{})

    assert {:error, _error} = AclRule.new(%{})

    ConnectorContracts.assert_struct_defaults(
      FreeBusy,
      %{
        time_min: "2026-05-06T00:00:00Z",
        time_max: "2026-05-07T00:00:00Z"
      },
      calendars: %{},
      groups: %{},
      busy: [],
      errors: [],
      metadata: %{}
    )

    assert {:error, _error} = FreeBusy.new(%{time_min: "2026-05-06T00:00:00Z"})
  end

  defp recorded(name), do: LiveSmoke.fixture!(:google_calendar, name)

  defp attendee!(event, email) do
    assert [attendee] = Enum.filter(event.attendees, &(&1.email == email))
    attendee
  end
end
