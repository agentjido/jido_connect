defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.GetScheduleTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftCalendar.Handlers.Actions.GetSchedule

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
    test "gets free/busy schedule for multiple users" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/me/calendar/getSchedule"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["schedules"] == ["meganb@contoso.com", "brianj@contoso.com"]
        assert decoded["startTime"]["dateTime"] == "2026-06-15T09:00:00"
        assert decoded["startTime"]["timeZone"] == "Pacific Standard Time"
        assert decoded["endTime"]["dateTime"] == "2026-06-15T18:00:00"
        assert decoded["endTime"]["timeZone"] == "Pacific Standard Time"
        assert decoded["availabilityViewInterval"] == 30

        Req.Test.json(conn, %{
          "@odata.context" =>
            "https://graph.microsoft.com/v1.0/$metadata#Collection(microsoft.graph.scheduleInformation)",
          "value" => [
            %{
              "scheduleId" => "meganb@contoso.com",
              "availabilityView" => "110022001100",
              "scheduleItems" => [
                %{
                  "start" => %{
                    "dateTime" => "2026-06-15T09:00:00",
                    "timeZone" => "Pacific Standard Time"
                  },
                  "end" => %{
                    "dateTime" => "2026-06-15T10:00:00",
                    "timeZone" => "Pacific Standard Time"
                  },
                  "status" => "busy"
                },
                %{
                  "start" => %{
                    "dateTime" => "2026-06-15T12:00:00",
                    "timeZone" => "Pacific Standard Time"
                  },
                  "end" => %{
                    "dateTime" => "2026-06-15T13:00:00",
                    "timeZone" => "Pacific Standard Time"
                  },
                  "status" => "tentative"
                }
              ],
              "workingHours" => %{
                "timeZone" => %{"name" => "Pacific Standard Time"},
                "daysOfWeek" => ["monday", "tuesday", "wednesday", "thursday", "friday"],
                "startTime" => "08:00:00",
                "endTime" => "17:00:00"
              }
            },
            %{
              "scheduleId" => "brianj@contoso.com",
              "availabilityView" => "000011000000",
              "scheduleItems" => [
                %{
                  "start" => %{
                    "dateTime" => "2026-06-15T14:00:00",
                    "timeZone" => "Pacific Standard Time"
                  },
                  "end" => %{
                    "dateTime" => "2026-06-15T16:00:00",
                    "timeZone" => "Pacific Standard Time"
                  },
                  "status" => "busy"
                }
              ],
              "error" => %{
                "responseCode" => "ErrorFreeBusyAccessDenied",
                "message" => "Cannot retrieve free/busy data for the specified user."
              }
            }
          ]
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      input = %{
        schedules: ["meganb@contoso.com", "brianj@contoso.com"],
        start_date_time: "2026-06-15T09:00:00",
        end_date_time: "2026-06-15T18:00:00",
        time_zone: "Pacific Standard Time",
        availability_view_interval: 30
      }

      assert {:ok, %{results: results}} = GetSchedule.run(input, context)

      assert length(results) == 2

      [first, second] = results
      assert first.schedule_id == "meganb@contoso.com"
      assert first.availability_view == "110022001100"
      assert length(first.slots) == 2
      assert hd(first.slots).status == "busy"
      assert hd(first.slots).start.date_time == "2026-06-15T09:00:00"

      assert second.schedule_id == "brianj@contoso.com"
      assert length(second.slots) == 1
      assert second.error["responseCode"] == "ErrorFreeBusyAccessDenied"
    end

    test "uses UTC timezone by default when time_zone not provided" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["startTime"]["timeZone"] == "UTC"
        assert decoded["endTime"]["timeZone"] == "UTC"

        Req.Test.json(conn, %{"value" => []})
      end)

      context = %{credentials: %{access_token: "test-token"}}

      input = %{
        schedules: ["user@contoso.com"],
        start_date_time: "2026-06-15T09:00:00",
        end_date_time: "2026-06-15T18:00:00"
      }

      assert {:ok, %{results: []}} = GetSchedule.run(input, context)
    end

    test "omits availabilityViewInterval when not provided" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        refute Map.has_key?(decoded, "availabilityViewInterval")

        Req.Test.json(conn, %{"value" => []})
      end)

      context = %{credentials: %{access_token: "test-token"}}

      input = %{
        schedules: ["user@contoso.com"],
        start_date_time: "2026-06-15T09:00:00",
        end_date_time: "2026-06-15T18:00:00"
      }

      assert {:ok, %{results: []}} = GetSchedule.run(input, context)
    end

    test "returns error when schedules is missing or empty" do
      context = %{credentials: %{access_token: "test-token"}}

      input_missing = %{
        start_date_time: "2026-06-15T09:00:00",
        end_date_time: "2026-06-15T18:00:00"
      }

      assert {:error, :invalid_schedule_input} = GetSchedule.run(input_missing, context)

      input_empty = %{
        schedules: [],
        start_date_time: "2026-06-15T09:00:00",
        end_date_time: "2026-06-15T18:00:00"
      }

      assert {:error, :invalid_schedule_input} = GetSchedule.run(input_empty, context)
    end

    test "returns error when start_date_time is missing" do
      context = %{credentials: %{access_token: "test-token"}}

      input = %{
        schedules: ["user@contoso.com"],
        end_date_time: "2026-06-15T18:00:00"
      }

      assert {:error, :invalid_schedule_input} = GetSchedule.run(input, context)
    end

    test "returns error when end_date_time is missing" do
      context = %{credentials: %{access_token: "test-token"}}

      input = %{
        schedules: ["user@contoso.com"],
        start_date_time: "2026-06-15T09:00:00"
      }

      assert {:error, :invalid_schedule_input} = GetSchedule.run(input, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = GetSchedule.run(%{}, %{})
    end

    test "returns error for HTTP error responses" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(500), %{
          "error" => %{"message" => "Internal server error"}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      input = %{
        schedules: ["user@contoso.com"],
        start_date_time: "2026-06-15T09:00:00",
        end_date_time: "2026-06-15T18:00:00"
      }

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               GetSchedule.run(input, context)
    end

    test "returns error for HTTP 401 unauthorized" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(401), %{
          "error" => %{
            "code" => "InvalidAuthenticationToken",
            "message" => "Access token has expired."
          }
        })
      end)

      context = %{credentials: %{access_token: "expired-token"}}

      input = %{
        schedules: ["user@contoso.com"],
        start_date_time: "2026-06-15T09:00:00",
        end_date_time: "2026-06-15T18:00:00"
      }

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 401}} =
               GetSchedule.run(input, context)
    end

    test "returns error for malformed success response missing value array" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{"@odata.context" => "something"})
      end)

      context = %{credentials: %{access_token: "test-token"}}

      input = %{
        schedules: ["user@contoso.com"],
        start_date_time: "2026-06-15T09:00:00",
        end_date_time: "2026-06-15T18:00:00"
      }

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               GetSchedule.run(input, context)
    end
  end
end
