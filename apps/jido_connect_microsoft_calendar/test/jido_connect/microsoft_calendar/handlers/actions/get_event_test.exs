defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.GetEventTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftCalendar.Handlers.Actions.GetEvent

  setup do
    Application.put_env(:jido_connect_microsoft, :microsoft_graph_base_url, "https://graph.test")

    Application.put_env(:jido_connect_microsoft, :microsoft_req_options,
      plug: {Req.Test, __MODULE__},
      retry: false
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_microsoft, :microsoft_graph_base_url)
      Application.delete_env(:jido_connect_microsoft, :microsoft_req_options)
    end)
  end

  describe "run/2" do
    test "fetches a single event by id from default calendar" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/me/events/AAMkEV1AAA="
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        Req.Test.json(conn, %{
          "id" => "AAMkEV1AAA=",
          "iCalUId" => "040000008200E00074C5B7101A82E008",
          "subject" => "Quarterly planning sync",
          "bodyPreview" => "Please join us for the quarterly planning meeting.",
          "body" => %{
            "contentType" => "html",
            "content" => "<html><body><p>Please join us for the meeting.</p></body></html>"
          },
          "start" => %{
            "dateTime" => "2026-06-15T10:00:00",
            "timeZone" => "Pacific Standard Time"
          },
          "end" => %{
            "dateTime" => "2026-06-15T11:30:00",
            "timeZone" => "Pacific Standard Time"
          },
          "organizer" => %{
            "emailAddress" => %{
              "name" => "Megan Bowen",
              "address" => "meganb@contoso.com"
            }
          },
          "attendees" => [
            %{
              "type" => "required",
              "status" => %{"response" => "accepted", "time" => "2026-05-19T14:00:00Z"},
              "emailAddress" => %{
                "name" => "Brian Johnson",
                "address" => "brianj@contoso.com"
              }
            },
            %{
              "type" => "optional",
              "status" => %{"response" => "none", "time" => "0001-01-01T00:00:00Z"},
              "emailAddress" => %{
                "name" => "All Users",
                "address" => "allusers@contoso.com"
              }
            }
          ],
          "location" => %{
            "displayName" => "Conference Room 1",
            "locationUri" => "https://contoso.com/rooms/cr1",
            "locationType" => "conferenceRoom"
          },
          "recurrence" => %{
            "pattern" => %{
              "type" => "weekly",
              "interval" => 2,
              "daysOfWeek" => ["monday"]
            },
            "range" => %{
              "type" => "endDate",
              "startDate" => "2026-06-15",
              "endDate" => "2026-12-31"
            }
          },
          "isAllDay" => false,
          "isCancelled" => false,
          "isOrganizer" => true,
          "sensitivity" => "normal",
          "showAs" => "busy",
          "hasAttachments" => false,
          "onlineMeetingUrl" => "https://teams.microsoft.com/l/meetup/19abc123"
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{event: event}} =
               GetEvent.run(%{event_id: "AAMkEV1AAA="}, context)

      assert event.event_id == "AAMkEV1AAA="
      assert event.subject == "Quarterly planning sync"
      assert event.start.date_time == "2026-06-15T10:00:00"
      assert event.start.time_zone == "Pacific Standard Time"
      assert event.end.date_time == "2026-06-15T11:30:00"
      assert event.organizer.name == "Megan Bowen"
      assert length(event.attendees) == 2
      assert event.location.display_name == "Conference Room 1"
      assert event.recurrence.pattern.type == "weekly"
      assert event.recurrence.range.type == "endDate"
      assert event.body_summary.content_type == "html"
      assert is_integer(event.body_summary.body_size)
      assert event.is_all_day == false
      assert event.sensitivity == "normal"
      assert event.show_as == "busy"
    end

    test "fetches a single event by id from a specific calendar" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/me/calendars/CAL123/events/EVT456"

        Req.Test.json(conn, %{
          "id" => "EVT456",
          "subject" => "Specific calendar event"
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{event: event}} =
               GetEvent.run(%{event_id: "EVT456", calendar_id: "CAL123"}, context)

      assert event.event_id == "EVT456"
      assert event.subject == "Specific calendar event"
    end

    test "returns error when event_id is missing" do
      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, :event_id_required} = GetEvent.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = GetEvent.run(%{}, %{})
    end

    test "returns error for HTTP 404" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(404), %{
          "error" => %{"message" => "The specified event was not found."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               GetEvent.run(%{event_id: "nonexistent"}, context)
    end

    test "returns error for HTTP 403 forbidden" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(403), %{
          "error" => %{
            "code" => "ErrorAccessDenied",
            "message" => "Access is denied. Check credentials and try again."
          }
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 403}} =
               GetEvent.run(%{event_id: "restricted"}, context)
    end
  end
end
