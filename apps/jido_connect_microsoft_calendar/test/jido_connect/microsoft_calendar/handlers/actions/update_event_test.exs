defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.UpdateEventTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftCalendar.Handlers.Actions.UpdateEvent

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
    test "updates an event subject on default calendar" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/me/events/AAMkEV_UPD_001"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["subject"] == "Updated subject"
        refute Map.has_key?(decoded, "start")
        refute Map.has_key?(decoded, "end")

        Req.Test.json(conn, %{
          "id" => "AAMkEV_UPD_001",
          "subject" => "Updated subject",
          "bodyPreview" => "Updated event",
          "start" => %{"dateTime" => "2026-06-15T10:00:00", "timeZone" => "UTC"},
          "end" => %{"dateTime" => "2026-06-15T11:00:00", "timeZone" => "UTC"},
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
               UpdateEvent.run(%{event_id: "AAMkEV_UPD_001", subject: "Updated subject"}, context)

      assert event.event_id == "AAMkEV_UPD_001"
      assert event.subject == "Updated subject"
    end

    test "updates an event on a specific calendar" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/me/calendars/CAL456/events/AAMkEV_UPD_002"

        Req.Test.json(conn, %{
          "id" => "AAMkEV_UPD_002",
          "subject" => "Moved event"
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{event: event}} =
               UpdateEvent.run(
                 %{
                   event_id: "AAMkEV_UPD_002",
                   calendar_id: "CAL456",
                   subject: "Moved event"
                 },
                 context
               )

      assert event.event_id == "AAMkEV_UPD_002"
    end

    test "updates time and location" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["start"]["dateTime"] == "2026-06-20T14:00:00"
        assert decoded["start"]["timeZone"] == "Pacific Standard Time"
        assert decoded["end"]["dateTime"] == "2026-06-20T15:30:00"
        assert decoded["location"]["displayName"] == "Room 42"

        Req.Test.json(conn, %{
          "id" => "AAMkEV_UPD_003",
          "subject" => "Rescheduled",
          "start" => %{"dateTime" => "2026-06-20T14:00:00", "timeZone" => "Pacific Standard Time"},
          "end" => %{"dateTime" => "2026-06-20T15:30:00", "timeZone" => "Pacific Standard Time"},
          "location" => %{"displayName" => "Room 42"},
          "attendees" => [],
          "isAllDay" => false,
          "showAs" => "busy"
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{event: event}} =
               UpdateEvent.run(
                 %{
                   event_id: "AAMkEV_UPD_003",
                   start_date_time: "2026-06-20T14:00:00",
                   end_date_time: "2026-06-20T15:30:00",
                   time_zone: "Pacific Standard Time",
                   location: "Room 42"
                 },
                 context
               )

      assert event.start.date_time == "2026-06-20T14:00:00"
      assert event.end.date_time == "2026-06-20T15:30:00"
      assert event.location.display_name == "Room 42"
    end

    test "updates attendees" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert length(decoded["attendees"]) == 2

        addresses =
          Enum.map(decoded["attendees"], fn a ->
            get_in(a, ["emailAddress", "address"])
          end)

        assert "alice@contoso.com" in addresses
        assert "bob@contoso.com" in addresses

        Req.Test.json(conn, %{
          "id" => "AAMkEV_UPD_004",
          "subject" => "With attendees",
          "attendees" => [
            %{
              "type" => "required",
              "emailAddress" => %{"name" => "Alice", "address" => "alice@contoso.com"}
            },
            %{
              "type" => "required",
              "emailAddress" => %{"name" => "Bob", "address" => "bob@contoso.com"}
            }
          ],
          "start" => %{"dateTime" => "2026-06-15T10:00:00", "timeZone" => "UTC"},
          "end" => %{"dateTime" => "2026-06-15T11:00:00", "timeZone" => "UTC"},
          "location" => %{},
          "isAllDay" => false,
          "showAs" => "busy"
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{event: event}} =
               UpdateEvent.run(
                 %{
                   event_id: "AAMkEV_UPD_004",
                   attendees: ["alice@contoso.com", "bob@contoso.com"]
                 },
                 context
               )

      assert length(event.attendees) == 2
    end

    test "sends empty JSON body for no-update fields" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded == %{}

        Req.Test.json(conn, %{
          "id" => "AAMkEV_UPD_005",
          "subject" => "Unchanged"
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:ok, %{event: event}} =
               UpdateEvent.run(%{event_id: "AAMkEV_UPD_005"}, context)

      assert event.event_id == "AAMkEV_UPD_005"
    end

    test "returns error when event_id is missing" do
      context = %{credentials: %{access_token: "test-token"}}
      assert {:error, :event_id_required} = UpdateEvent.run(%{}, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = UpdateEvent.run(%{}, %{})
    end

    test "returns error for HTTP 404 not found" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(404), %{
          "error" => %{"message" => "The specified event was not found."}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 404}} =
               UpdateEvent.run(%{event_id: "nonexistent"}, context)
    end

    test "returns error for HTTP 403 forbidden" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(403), %{
          "error" => %{
            "code" => "ErrorAccessDenied",
            "message" => "Cannot update events in this calendar."
          }
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 403}} =
               UpdateEvent.run(%{event_id: "restricted"}, context)
    end
  end
end
