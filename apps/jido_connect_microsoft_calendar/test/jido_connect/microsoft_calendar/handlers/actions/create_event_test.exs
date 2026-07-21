defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.CreateEventTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftCalendar.Handlers.Actions.CreateEvent

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
    test "creates an event with required fields on default calendar" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/me/calendar/events"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["subject"] == "Team standup"
        assert decoded["start"]["dateTime"] == "2026-06-15T09:00:00"
        assert decoded["start"]["timeZone"] == "UTC"
        assert decoded["end"]["dateTime"] == "2026-06-15T09:30:00"
        assert decoded["end"]["timeZone"] == "UTC"

        Req.Test.json(conn |> Plug.Conn.put_status(201), %{
          "id" => "AAMkEV_NEW_001",
          "subject" => "Team standup",
          "bodyPreview" => "Daily standup",
          "start" => %{"dateTime" => "2026-06-15T09:00:00", "timeZone" => "UTC"},
          "end" => %{"dateTime" => "2026-06-15T09:30:00", "timeZone" => "UTC"},
          "organizer" => %{
            "emailAddress" => %{"name" => "Megan Bowen", "address" => "meganb@contoso.com"}
          },
          "attendees" => [],
          "location" => %{},
          "isAllDay" => false,
          "showAs" => "busy"
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{event: event}} =
               CreateEvent.run(
                 %{
                   subject: "Team standup",
                   start_date_time: "2026-06-15T09:00:00",
                   end_date_time: "2026-06-15T09:30:00"
                 },
                 context
               )

      assert event.event_id == "AAMkEV_NEW_001"
      assert event.subject == "Team standup"
      assert event.start.date_time == "2026-06-15T09:00:00"
      assert event.end.date_time == "2026-06-15T09:30:00"
    end

    test "creates an event on a specific calendar" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/me/calendars/CAL999/events"

        Req.Test.json(conn |> Plug.Conn.put_status(201), %{
          "id" => "AAMkEV_NEW_002",
          "subject" => "Sprint planning"
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{event: event}} =
               CreateEvent.run(
                 %{
                   calendar_id: "CAL999",
                   subject: "Sprint planning",
                   start_date_time: "2026-06-16T10:00:00",
                   end_date_time: "2026-06-16T11:00:00"
                 },
                 context
               )

      assert event.event_id == "AAMkEV_NEW_002"
    end

    test "creates an event with full fields" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["subject"] == "Quarterly review"
        assert decoded["body"]["contentType"] == "html"
        assert decoded["body"]["content"] == "<p>Review slides</p>"
        assert decoded["start"]["dateTime"] == "2026-06-20T14:00:00"
        assert decoded["start"]["timeZone"] == "Pacific Standard Time"
        assert decoded["end"]["dateTime"] == "2026-06-20T15:00:00"
        assert decoded["location"]["displayName"] == "Board Room"
        assert length(decoded["attendees"]) == 2
        assert decoded["isAllDay"] == false
        assert decoded["sensitivity"] == "private"
        assert decoded["showAs"] == "busy"

        Req.Test.json(conn |> Plug.Conn.put_status(201), %{
          "id" => "AAMkEV_NEW_003",
          "subject" => "Quarterly review",
          "bodyPreview" => "Review slides",
          "start" => %{"dateTime" => "2026-06-20T14:00:00", "timeZone" => "Pacific Standard Time"},
          "end" => %{"dateTime" => "2026-06-20T15:00:00", "timeZone" => "Pacific Standard Time"},
          "organizer" => %{
            "emailAddress" => %{"name" => "Megan Bowen", "address" => "meganb@contoso.com"}
          },
          "attendees" => [
            %{
              "type" => "required",
              "emailAddress" => %{"name" => "Alice", "address" => "alice@contoso.com"}
            },
            %{
              "type" => "optional",
              "emailAddress" => %{"name" => "Bob", "address" => "bob@contoso.com"}
            }
          ],
          "location" => %{"displayName" => "Board Room"},
          "isAllDay" => false,
          "sensitivity" => "private",
          "showAs" => "busy"
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{event: event}} =
               CreateEvent.run(
                 %{
                   subject: "Quarterly review",
                   body: "<p>Review slides</p>",
                   content_type: "html",
                   start_date_time: "2026-06-20T14:00:00",
                   end_date_time: "2026-06-20T15:00:00",
                   time_zone: "Pacific Standard Time",
                   location: "Board Room",
                   attendees: ["alice@contoso.com", "bob@contoso.com"],
                   is_all_day: false,
                   sensitivity: "private",
                   show_as: "busy"
                 },
                 context
               )

      assert event.event_id == "AAMkEV_NEW_003"
      assert event.subject == "Quarterly review"
      assert event.location.display_name == "Board Room"
      assert length(event.attendees) == 2
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = CreateEvent.run(%{}, %{})
    end

    test "returns error for HTTP 400 bad request" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(400), %{
          "error" => %{"message" => "Invalid start/end date time values."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 400}} =
               CreateEvent.run(
                 %{subject: "bad", start_date_time: "invalid", end_date_time: "invalid"},
                 context
               )
    end

    test "returns error for HTTP 403 forbidden" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(403), %{
          "error" => %{
            "code" => "ErrorAccessDenied",
            "message" => "Access is denied."
          }
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 403}} =
               CreateEvent.run(
                 %{
                   subject: "test",
                   start_date_time: "2026-06-15T09:00:00",
                   end_date_time: "2026-06-15T10:00:00"
                 },
                 context
               )
    end

    test "returns error for HTTP 401 unauthorized" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(401), %{
          "error" => %{"message" => "Token is expired."}
        })
      end)

      context = %{credentials: %{access_token: "expired-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 401}} =
               CreateEvent.run(
                 %{
                   subject: "test",
                   start_date_time: "2026-06-15T09:00:00",
                   end_date_time: "2026-06-15T10:00:00"
                 },
                 context
               )
    end
  end
end
