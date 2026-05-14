defmodule Jido.Connect.Google.Calendar.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Google.Calendar.{AclRule, Calendar, Channel, Client, Event}

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(
      :jido_connect_google_calendar,
      :google_calendar_api_base_url,
      "https://calendar.test"
    )

    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_google_calendar, :google_calendar_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  test "lists calendars" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/users/me/calendarList"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]
      assert conn.query_params["maxResults"] == "50"
      assert conn.query_params["showHidden"] == "true"
      assert conn.query_params["showDeleted"] == "false"
      assert conn.query_params["fields"] =~ "items(id,summary"

      Req.Test.json(conn, %{
        "items" => [
          %{
            "id" => "primary",
            "summary" => "Primary Calendar",
            "timeZone" => "America/Chicago",
            "primary" => true,
            "accessRole" => "owner"
          }
        ],
        "nextSyncToken" => "calendar-sync"
      })
    end)

    assert {:ok, %{calendars: [%Calendar{} = calendar], next_sync_token: "calendar-sync"}} =
             Client.list_calendars(
               %{page_size: 50, show_hidden: true, show_deleted: false},
               "token"
             )

    assert calendar.calendar_id == "primary"
    assert calendar.primary?
  end

  test "returns provider errors for malformed calendar list items" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/users/me/calendarList"

      Req.Test.json(conn, %{
        "items" => [
          %{"summary" => "Missing id"}
        ]
      })
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} = Client.list_calendars(%{}, "token")
  end

  test "lists events" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/calendars/primary/events"
      assert conn.query_params["maxResults"] == "10"
      assert conn.query_params["singleEvents"] == "true"
      assert conn.query_params["showDeleted"] == "false"
      assert conn.query_params["timeMin"] == "2026-05-06T00:00:00Z"
      assert conn.query_params["timeMax"] == "2026-05-07T00:00:00Z"
      assert conn.query_params["fields"] =~ "nextSyncToken,items"

      Req.Test.json(conn, %{
        "items" => [
          %{
            "id" => "event123",
            "status" => "confirmed",
            "summary" => "Planning",
            "start" => %{"dateTime" => "2026-05-06T09:00:00-05:00"},
            "end" => %{"dateTime" => "2026-05-06T10:00:00-05:00"}
          }
        ],
        "nextPageToken" => "events-next"
      })
    end)

    assert {:ok, %{events: [%Event{} = event], next_page_token: "events-next"}} =
             Client.list_events(
               %{
                 calendar_id: "primary",
                 page_size: 10,
                 single_events: true,
                 show_deleted: false,
                 time_min: "2026-05-06T00:00:00Z",
                 time_max: "2026-05-07T00:00:00Z"
               },
               "token"
             )

    assert event.event_id == "event123"
    assert event.calendar_id == "primary"
    assert event.summary == "Planning"
  end

  test "gets events" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/calendars/primary/events/event123"
      assert conn.query_params["maxAttendees"] == "10"
      assert conn.query_params["timeZone"] == "America/Chicago"
      assert conn.query_params["fields"] =~ "id,iCalUID,status"

      Req.Test.json(conn, %{
        "id" => "event123",
        "status" => "confirmed",
        "summary" => "Planning",
        "start" => %{"dateTime" => "2026-05-06T09:00:00-05:00"},
        "end" => %{"dateTime" => "2026-05-06T10:00:00-05:00"}
      })
    end)

    assert {:ok, %Event{} = event} =
             Client.get_event(
               %{
                 calendar_id: "primary",
                 event_id: "event123",
                 max_attendees: 10,
                 time_zone: "America/Chicago"
               },
               "token"
             )

    assert event.event_id == "event123"
    assert event.calendar_id == "primary"
  end

  test "creates events" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/calendars/primary/events"
      assert conn.query_params["sendUpdates"] == "all"
      assert conn.query_params["conferenceDataVersion"] == "1"
      assert conn.query_params["fields"] =~ "id,iCalUID,status"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "summary" => "Planning",
               "start" => %{
                 "dateTime" => "2026-05-06T09:00:00-05:00",
                 "timeZone" => "America/Chicago"
               },
               "end" => %{
                 "dateTime" => "2026-05-06T10:00:00-05:00",
                 "timeZone" => "America/Chicago"
               },
               "attendees" => [
                 %{
                   "email" => "guest@example.com",
                   "responseStatus" => "accepted"
                 }
               ],
               "recurrence" => ["RRULE:FREQ=DAILY;COUNT=2"]
             }

      Req.Test.json(conn, %{
        "id" => "created123",
        "status" => "confirmed",
        "summary" => "Planning",
        "start" => %{"dateTime" => "2026-05-06T09:00:00-05:00"},
        "end" => %{"dateTime" => "2026-05-06T10:00:00-05:00"}
      })
    end)

    assert {:ok, %Event{} = event} =
             Client.create_event(
               %{
                 calendar_id: "primary",
                 summary: "Planning",
                 start: "2026-05-06T09:00:00-05:00",
                 end: "2026-05-06T10:00:00-05:00",
                 time_zone: "America/Chicago",
                 attendees: [
                   %{email: "guest@example.com", response_status: "accepted"}
                 ],
                 recurrence: ["RRULE:FREQ=DAILY;COUNT=2"],
                 send_updates: "all",
                 conference_data_version: 1
               },
               "token"
             )

    assert event.event_id == "created123"
    assert event.calendar_id == "primary"
  end

  test "updates events" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/v3/calendars/primary/events/event123"
      assert conn.query_params["sendUpdates"] == "externalOnly"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "summary" => "Updated",
               "transparency" => "transparent"
             }

      Req.Test.json(conn, %{
        "id" => "event123",
        "status" => "confirmed",
        "summary" => "Updated",
        "start" => %{"dateTime" => "2026-05-06T09:00:00-05:00"},
        "end" => %{"dateTime" => "2026-05-06T10:00:00-05:00"}
      })
    end)

    assert {:ok, %Event{} = event} =
             Client.update_event(
               %{
                 calendar_id: "primary",
                 event_id: "event123",
                 summary: "Updated",
                 transparency: "transparent",
                 send_updates: "externalOnly"
               },
               "token"
             )

    assert event.event_id == "event123"
    assert event.summary == "Updated"
  end

  test "deletes events" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v3/calendars/primary/events/event123"
      assert conn.query_params["sendUpdates"] == "all"

      Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok, %{calendar_id: "primary", event_id: "event123", deleted?: true}} =
             Client.delete_event(
               %{calendar_id: "primary", event_id: "event123", send_updates: "all"},
               "token"
             )
  end

  test "calls calendar resource endpoints" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer token"]

      case {conn.method, conn.request_path} do
        {"GET", "/v3/calendars/primary"} ->
          assert conn.query_params["fields"] == "id,summary"

          Req.Test.json(conn, %{
            "id" => "primary",
            "summary" => "Primary Calendar",
            "conferenceProperties" => %{
              "allowedConferenceSolutionTypes" => ["hangoutsMeet"]
            }
          })

        {"POST", "/v3/calendars"} ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)

          assert Jason.decode!(body) == %{
                   "summary" => "Team",
                   "timeZone" => "America/Chicago"
                 }

          Req.Test.json(conn, %{"id" => "team", "summary" => "Team"})

        {"PATCH", "/v3/calendars/team"} ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"summary" => "Team Updated"}

          Req.Test.json(conn, %{"id" => "team", "summary" => "Team Updated"})

        {"PUT", "/v3/calendars/team"} ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"summary" => "Team Replaced"}

          Req.Test.json(conn, %{"id" => "team", "summary" => "Team Replaced"})

        {"DELETE", "/v3/calendars/team"} ->
          Plug.Conn.resp(conn, 204, "")

        {"POST", "/v3/calendars/primary/clear"} ->
          Plug.Conn.resp(conn, 204, "")
      end
    end)

    assert {:ok, %Calendar{calendar_id: "primary", summary: "Primary Calendar"} = calendar} =
             Client.get_calendar(%{calendar_id: "primary", fields: "id,summary"}, "token")

    assert calendar.conference_properties == %{
             "allowedConferenceSolutionTypes" => ["hangoutsMeet"]
           }

    assert {:ok, %Calendar{calendar_id: "team", summary: "Team"}} =
             Client.create_calendar(
               %{summary: "Team", time_zone: "America/Chicago"},
               "token"
             )

    assert {:ok, %Calendar{summary: "Team Updated"}} =
             Client.patch_calendar(%{calendar_id: "team", summary: "Team Updated"}, "token")

    assert {:ok, %Calendar{summary: "Team Replaced"}} =
             Client.update_calendar(%{calendar_id: "team", summary: "Team Replaced"}, "token")

    assert {:ok, %{calendar_id: "team", deleted?: true}} =
             Client.delete_calendar(%{calendar_id: "team"}, "token")

    assert {:ok, %{calendar_id: "primary", cleared?: true}} =
             Client.clear_calendar(%{calendar_id: "primary"}, "token")
  end

  test "calls calendarList item endpoints" do
    Req.Test.stub(__MODULE__, fn conn ->
      case {conn.method, conn.request_path} do
        {"GET", "/v3/users/me/calendarList/primary"} ->
          assert conn.query_params["fields"] == "id,summary"
          Req.Test.json(conn, %{"id" => "primary", "summary" => "Primary"})

        {"POST", "/v3/users/me/calendarList"} ->
          assert conn.query_params["colorRgbFormat"] == "true"
          {:ok, body, conn} = Plug.Conn.read_body(conn)

          assert Jason.decode!(body) == %{
                   "id" => "team",
                   "summaryOverride" => "Team Calendar",
                   "backgroundColor" => "#1a73e8"
                 }

          Req.Test.json(conn, %{
            "id" => "team",
            "summary" => "Team",
            "summaryOverride" => "Team Calendar"
          })

        {"PATCH", "/v3/users/me/calendarList/team"} ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"id" => "team", "hidden" => true}

          Req.Test.json(conn, %{"id" => "team", "summary" => "Team", "hidden" => true})

        {"PUT", "/v3/users/me/calendarList/team"} ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"id" => "team", "selected" => false}

          Req.Test.json(conn, %{"id" => "team", "summary" => "Team", "selected" => false})

        {"DELETE", "/v3/users/me/calendarList/team"} ->
          Plug.Conn.resp(conn, 204, "")
      end
    end)

    assert {:ok, %Calendar{calendar_id: "primary"}} =
             Client.get_calendar_list_entry(
               %{calendar_id: "primary", fields: "id,summary"},
               "token"
             )

    assert {:ok, %Calendar{summary_override: "Team Calendar"}} =
             Client.create_calendar_list_entry(
               %{
                 calendar_id: "team",
                 summary_override: "Team Calendar",
                 background_color: "#1a73e8",
                 color_rgb_format: true
               },
               "token"
             )

    assert {:ok, %Calendar{hidden?: true}} =
             Client.patch_calendar_list_entry(%{calendar_id: "team", hidden: true}, "token")

    assert {:ok, %Calendar{selected?: false}} =
             Client.update_calendar_list_entry(%{calendar_id: "team", selected: false}, "token")

    assert {:ok, %{calendar_id: "team", removed?: true}} =
             Client.delete_calendar_list_entry(%{calendar_id: "team"}, "token")
  end

  test "calls ACL endpoints" do
    Req.Test.stub(__MODULE__, fn conn ->
      case {conn.method, conn.request_path} do
        {"GET", "/v3/calendars/primary/acl"} ->
          assert conn.query_params["maxResults"] == "20"
          assert conn.query_params["showDeleted"] == "true"
          assert conn.query_params["fields"] =~ "items(id,etag"

          Req.Test.json(conn, %{
            "items" => [
              %{
                "id" => "rule123",
                "role" => "reader",
                "scope" => %{"type" => "user", "value" => "guest@example.com"}
              }
            ],
            "nextSyncToken" => "acl-sync"
          })

        {"GET", "/v3/calendars/primary/acl/rule123"} ->
          assert conn.query_params["fields"] == "id,role,scope"

          Req.Test.json(conn, %{
            "id" => "rule123",
            "role" => "reader",
            "scope" => %{"type" => "user", "value" => "guest@example.com"}
          })

        {"POST", "/v3/calendars/primary/acl"} ->
          assert conn.query_params["sendNotifications"] == "true"
          {:ok, body, conn} = Plug.Conn.read_body(conn)

          assert Jason.decode!(body) == %{
                   "role" => "reader",
                   "scope" => %{"type" => "user", "value" => "guest@example.com"}
                 }

          Req.Test.json(conn, %{
            "id" => "rule123",
            "role" => "reader",
            "scope" => %{"type" => "user", "value" => "guest@example.com"}
          })

        {"PATCH", "/v3/calendars/primary/acl/rule123"} ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert Jason.decode!(body) == %{"role" => "writer", "scope" => %{}}

          Req.Test.json(conn, %{
            "id" => "rule123",
            "role" => "writer",
            "scope" => %{"type" => "user", "value" => "guest@example.com"}
          })

        {"PUT", "/v3/calendars/primary/acl/rule123"} ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)

          assert Jason.decode!(body) == %{
                   "role" => "reader",
                   "scope" => %{"type" => "user", "value" => "guest@example.com"}
                 }

          Req.Test.json(conn, %{
            "id" => "rule123",
            "role" => "reader",
            "scope" => %{"type" => "user", "value" => "guest@example.com"}
          })

        {"DELETE", "/v3/calendars/primary/acl/rule123"} ->
          Plug.Conn.resp(conn, 204, "")
      end
    end)

    assert {:ok, %{acl_rules: [%AclRule{acl_rule_id: "rule123"}], next_sync_token: "acl-sync"}} =
             Client.list_acl(
               %{calendar_id: "primary", page_size: 20, show_deleted: true},
               "token"
             )

    assert {:ok, %AclRule{role: "reader"}} =
             Client.get_acl(
               %{calendar_id: "primary", acl_rule_id: "rule123", fields: "id,role,scope"},
               "token"
             )

    assert {:ok, %AclRule{scope_value: "guest@example.com"}} =
             Client.create_acl(
               %{
                 calendar_id: "primary",
                 role: "reader",
                 scope_type: "user",
                 scope_value: "guest@example.com",
                 send_notifications: true
               },
               "token"
             )

    assert {:ok, %AclRule{role: "writer"}} =
             Client.patch_acl(
               %{calendar_id: "primary", acl_rule_id: "rule123", role: "writer"},
               "token"
             )

    assert {:ok, %AclRule{role: "reader"}} =
             Client.update_acl(
               %{
                 calendar_id: "primary",
                 acl_rule_id: "rule123",
                 role: "reader",
                 scope_type: "user",
                 scope_value: "guest@example.com"
               },
               "token"
             )

    assert {:ok, %{calendar_id: "primary", acl_rule_id: "rule123", deleted?: true}} =
             Client.delete_acl(%{calendar_id: "primary", acl_rule_id: "rule123"}, "token")
  end

  test "calls event utility endpoints" do
    Req.Test.stub(__MODULE__, fn conn ->
      case {conn.method, conn.request_path} do
        {"GET", "/v3/calendars/primary/events/series123/instances"} ->
          assert conn.query_params["maxResults"] == "5"
          assert conn.query_params["showDeleted"] == "false"
          assert conn.query_params["originalStart"] == "2026-05-06T09:00:00-05:00"

          Req.Test.json(conn, %{
            "items" => [
              %{
                "id" => "instance123",
                "status" => "confirmed",
                "summary" => "Standup",
                "start" => %{"dateTime" => "2026-05-06T09:00:00-05:00"},
                "end" => %{"dateTime" => "2026-05-06T09:30:00-05:00"}
              }
            ],
            "nextPageToken" => "instances-next"
          })

        {"POST", "/v3/calendars/primary/events/event123/move"} ->
          assert conn.query_params["destination"] == "team"
          assert conn.query_params["sendUpdates"] == "all"

          Req.Test.json(conn, %{
            "id" => "event123",
            "status" => "confirmed",
            "summary" => "Moved",
            "start" => %{"dateTime" => "2026-05-06T09:00:00-05:00"},
            "end" => %{"dateTime" => "2026-05-06T10:00:00-05:00"}
          })
      end
    end)

    assert {:ok, %{events: [%Event{event_id: "instance123"}], next_page_token: "instances-next"}} =
             Client.list_event_instances(
               %{
                 calendar_id: "primary",
                 event_id: "series123",
                 page_size: 5,
                 show_deleted: false,
                 original_start: "2026-05-06T09:00:00-05:00"
               },
               "token"
             )

    assert {:ok, %Event{event_id: "event123", calendar_id: "team"}} =
             Client.move_event(
               %{
                 calendar_id: "primary",
                 event_id: "event123",
                 destination_calendar_id: "team",
                 send_updates: "all"
               },
               "token"
             )
  end

  test "watches events" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/calendars/primary/events/watch"
      assert conn.query_params["eventTypes"] == "default"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "id" => "event-channel",
               "type" => "web_hook",
               "address" => "https://example.com/calendar/events",
               "token" => "tenant=1",
               "params" => %{"ttl" => "3600"}
             }

      Req.Test.json(conn, %{
        "kind" => "api#channel",
        "id" => "event-channel",
        "resourceId" => "events-resource",
        "resourceUri" => "https://www.googleapis.com/calendar/v3/calendars/primary/events",
        "token" => "tenant=1",
        "expiration" => 1_779_000_000_000
      })
    end)

    assert {:ok, %Channel{} = channel} =
             Client.watch_events(
               %{
                 calendar_id: "primary",
                 channel_id: "event-channel",
                 address: "https://example.com/calendar/events",
                 token: "tenant=1",
                 ttl_seconds: 3600,
                 event_types: "default"
               },
               "token"
             )

    assert channel.channel_id == "event-channel"
    assert channel.resource_id == "events-resource"
    assert channel.expiration == "1779000000000"
  end

  test "watches calendar list" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/users/me/calendarList/watch"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "id" => "calendar-list-channel",
               "type" => "web_hook",
               "address" => "https://example.com/calendar/list"
             }

      Req.Test.json(conn, %{
        "kind" => "api#channel",
        "id" => "calendar-list-channel",
        "resourceId" => "calendar-list-resource",
        "resourceUri" => "https://www.googleapis.com/calendar/v3/users/me/calendarList"
      })
    end)

    assert {:ok, %Channel{channel_id: "calendar-list-channel"}} =
             Client.watch_calendar_list(
               %{
                 channel_id: "calendar-list-channel",
                 address: "https://example.com/calendar/list"
               },
               "token"
             )
  end

  test "watches ACL changes" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/calendars/primary/acl/watch"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "id" => "acl-channel",
               "type" => "web_hook",
               "address" => "https://example.com/calendar/acl"
             }

      Req.Test.json(conn, %{
        "kind" => "api#channel",
        "id" => "acl-channel",
        "resourceId" => "acl-resource",
        "resourceUri" => "https://www.googleapis.com/calendar/v3/calendars/primary/acl"
      })
    end)

    assert {:ok, %Channel{channel_id: "acl-channel"}} =
             Client.watch_acl(
               %{
                 calendar_id: "primary",
                 channel_id: "acl-channel",
                 address: "https://example.com/calendar/acl"
               },
               "token"
             )
  end

  test "watches settings" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/users/me/settings/watch"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "id" => "settings-channel",
               "type" => "web_hook",
               "address" => "https://example.com/calendar/settings"
             }

      Req.Test.json(conn, %{
        "kind" => "api#channel",
        "id" => "settings-channel",
        "resourceId" => "settings-resource",
        "resourceUri" => "https://www.googleapis.com/calendar/v3/users/me/settings"
      })
    end)

    assert {:ok, %Channel{channel_id: "settings-channel"}} =
             Client.watch_settings(
               %{
                 channel_id: "settings-channel",
                 address: "https://example.com/calendar/settings"
               },
               "token"
             )
  end

  test "stops channels" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/channels/stop"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "id" => "event-channel",
               "resourceId" => "events-resource"
             }

      Plug.Conn.resp(conn, 204, "")
    end)

    assert {:ok,
            %{
              channel_id: "event-channel",
              resource_id: "events-resource",
              stopped?: true
            }} =
             Client.stop_channel(
               %{channel_id: "event-channel", resource_id: "events-resource"},
               "token"
             )
  end

  test "queries freebusy" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v3/freeBusy"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "timeMin" => "2026-05-06T08:00:00Z",
               "timeMax" => "2026-05-06T11:00:00Z",
               "timeZone" => "UTC",
               "items" => [
                 %{"id" => "primary"},
                 %{"id" => "team@example.com"}
               ]
             }

      Req.Test.json(conn, %{
        "timeMin" => "2026-05-06T08:00:00Z",
        "timeMax" => "2026-05-06T11:00:00Z",
        "calendars" => %{
          "primary" => %{
            "busy" => [
              %{
                "start" => "2026-05-06T09:00:00Z",
                "end" => "2026-05-06T10:00:00Z"
              }
            ]
          }
        }
      })
    end)

    assert {:ok,
            %Jido.Connect.Google.Calendar.FreeBusy{
              busy: [
                %{
                  calendar_id: "primary",
                  start: "2026-05-06T09:00:00Z",
                  end: "2026-05-06T10:00:00Z"
                }
              ]
            }} =
             Client.query_free_busy(
               %{
                 calendar_ids: ["primary", "team@example.com"],
                 time_min: "2026-05-06T08:00:00Z",
                 time_max: "2026-05-06T11:00:00Z",
                 time_zone: "UTC"
               },
               "token"
             )
  end

  test "returns provider errors for malformed event responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v3/calendars/primary/events/event123"

      Req.Test.json(conn, %{
        "summary" => "Missing id"
      })
    end)

    assert {:error,
            %Jido.Connect.Error.ProviderError{
              provider: :google,
              reason: :invalid_response
            }} =
             Client.get_event(%{calendar_id: "primary", event_id: "event123"}, "token")
  end
end
