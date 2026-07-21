defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.ListEventsTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftCalendar.Handlers.Actions.ListEvents

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
    test "lists events from default calendar using calendarView with date range" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/me/calendar/calendarView"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]
        assert conn.query_params["startDateTime"] == "2026-06-01T00:00:00"
        assert conn.query_params["endDateTime"] == "2026-06-30T23:59:59"
        assert conn.query_params["$top"] == "25"

        Req.Test.json(conn, %{
          "@odata.context" =>
            "https://graph.microsoft.com/v1.0/$metadata#users('user')/calendarView",
          "@odata.nextLink" =>
            "https://graph.microsoft.com/v1.0/me/calendar/calendarView?$skip=25",
          "value" => [
            %{
              "id" => "AAMkEV1AAA=",
              "subject" => "Quarterly planning sync",
              "bodyPreview" => "Please join us for the quarterly planning meeting.",
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
                }
              ],
              "location" => %{"displayName" => "Conference Room 1"},
              "isAllDay" => false,
              "showAs" => "busy"
            },
            %{
              "id" => "AAMkEV2BBB=",
              "subject" => "Lunch with team",
              "bodyPreview" => "Casual lunch at the usual spot.",
              "start" => %{
                "dateTime" => "2026-06-16T12:00:00",
                "timeZone" => "Pacific Standard Time"
              },
              "end" => %{
                "dateTime" => "2026-06-16T13:00:00",
                "timeZone" => "Pacific Standard Time"
              },
              "organizer" => %{
                "emailAddress" => %{
                  "name" => "Brian Johnson",
                  "address" => "brianj@contoso.com"
                }
              },
              "attendees" => [],
              "isAllDay" => false,
              "showAs" => "free"
            }
          ]
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      input = %{
        start_date_time: "2026-06-01T00:00:00",
        end_date_time: "2026-06-30T23:59:59"
      }

      assert {:ok, %{events: events, next_link: next_link}} =
               ListEvents.run(input, context)

      assert length(events) == 2

      [first, second] = events
      assert first.subject == "Quarterly planning sync"
      assert first.start.date_time == "2026-06-15T10:00:00"
      assert first.start.time_zone == "Pacific Standard Time"
      assert first.end.date_time == "2026-06-15T11:30:00"
      assert length(first.attendees) == 1
      assert hd(first.attendees).name == "Brian Johnson"
      assert hd(first.attendees).address == "brianj@contoso.com"

      assert second.subject == "Lunch with team"
      assert next_link =~ "$skip=25"
    end

    test "lists events from a specific calendar with calendarView" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/me/calendars/CAL123/calendarView"
        assert conn.query_params["startDateTime"] == "2026-06-15T00:00:00"
        assert conn.query_params["endDateTime"] == "2026-06-15T23:59:59"

        Req.Test.json(conn, %{
          "value" => [
            %{
              "id" => "EVT-1",
              "subject" => "Team standup",
              "start" => %{"dateTime" => "2026-06-15T09:00:00", "timeZone" => "UTC"},
              "end" => %{"dateTime" => "2026-06-15T09:30:00", "timeZone" => "UTC"}
            }
          ]
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{events: events}} =
               ListEvents.run(
                 %{
                   calendar_id: "CAL123",
                   start_date_time: "2026-06-15T00:00:00",
                   end_date_time: "2026-06-15T23:59:59"
                 },
                 context
               )

      assert length(events) == 1
    end

    test "lists events without date range uses events endpoint" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/me/calendar/events"

        Req.Test.json(conn, %{
          "value" => [
            %{
              "id" => "EVT-NO-DATE",
              "subject" => "Undated event"
            }
          ]
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{events: events}} = ListEvents.run(%{}, context)
      assert length(events) == 1
    end

    test "lists events from specific calendar without date range" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/me/calendars/CAL456/events"

        Req.Test.json(conn, %{"value" => []})
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{events: []}} =
               ListEvents.run(%{calendar_id: "CAL456"}, context)
    end

    test "passes page_size and skip parameters" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.query_params["$top"] == "10"
        assert conn.query_params["$skip"] == "20"

        Req.Test.json(conn, %{"value" => []})
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{events: []}} =
               ListEvents.run(%{page_size: 10, skip: 20}, context)
    end

    test "handles empty event list" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"value" => []})
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{events: [], next_link: nil}} = ListEvents.run(%{}, context)
    end

    test "normalizes event with recurrence pattern" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "value" => [
            %{
              "id" => "EVT-REC",
              "subject" => "Weekly standup",
              "start" => %{"dateTime" => "2026-06-15T09:00:00", "timeZone" => "UTC"},
              "end" => %{"dateTime" => "2026-06-15T09:30:00", "timeZone" => "UTC"},
              "recurrence" => %{
                "pattern" => %{
                  "type" => "weekly",
                  "interval" => 1,
                  "daysOfWeek" => ["monday", "wednesday"]
                },
                "range" => %{
                  "type" => "endDate",
                  "startDate" => "2026-06-15",
                  "endDate" => "2026-12-31"
                }
              }
            }
          ]
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{events: [event]}} = ListEvents.run(%{}, context)

      assert event.recurrence.pattern.type == "weekly"
      assert event.recurrence.pattern.interval == 1
      assert event.recurrence.range.type == "endDate"
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = ListEvents.run(%{}, %{})
    end

    test "returns error for HTTP error responses" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(500), %{
          "error" => %{"message" => "Internal server error"}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               ListEvents.run(%{}, context)
    end

    test "returns error for HTTP 429 rate limited" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Plug.Conn.put_resp_header("retry-after", "30")
        |> Req.Test.json(%{
          "error" => %{
            "code" => "TooManyRequests",
            "message" => "Please retry later."
          }
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 429}} =
               ListEvents.run(%{}, context)
    end
  end
end
