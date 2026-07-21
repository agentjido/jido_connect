defmodule Jido.Connect.MicrosoftCalendar.Handlers.Actions.FindMeetingTimesTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.MicrosoftCalendar.Handlers.Actions.FindMeetingTimes

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
    test "finds meeting times with attendees and time window" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/me/findMeetingTimes"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert length(decoded["attendees"]) == 2
        assert hd(decoded["attendees"])["emailAddress"]["address"] == "meganb@contoso.com"
        assert hd(decoded["attendees"])["type"] == "required"

        assert decoded["timeConstraint"]["timeslots"] |> length() == 1

        [timeslot] = decoded["timeConstraint"]["timeslots"]
        assert timeslot["start"]["dateTime"] == "2026-06-15T09:00:00"
        assert timeslot["start"]["timeZone"] == "Pacific Standard Time"
        assert timeslot["end"]["dateTime"] == "2026-06-15T18:00:00"

        assert decoded["meetingDuration"] == "PT1H"
        assert decoded["returnSuggestionReasons"] == true

        Req.Test.json(conn, %{
          "emptySuggestionsReason" => nil,
          "meetingTimeSuggestions" => [
            %{
              "confidence" => 100,
              "locations" => [%{"displayName" => "Conference Room 1"}],
              "meetingTimeSlot" => %{
                "start" => %{
                  "dateTime" => "2026-06-15T10:00:00",
                  "timeZone" => "Pacific Standard Time"
                },
                "end" => %{
                  "dateTime" => "2026-06-15T11:00:00",
                  "timeZone" => "Pacific Standard Time"
                }
              },
              "order" => 1,
              "organizerAvailability" => "free",
              "attendeeAvailability" => [
                %{
                  "attendee" => %{
                    "type" => "required",
                    "emailAddress" => %{
                      "name" => "Megan Bowen",
                      "address" => "meganb@contoso.com"
                    }
                  },
                  "availability" => "free"
                },
                %{
                  "attendee" => %{
                    "type" => "required",
                    "emailAddress" => %{
                      "name" => "Brian Johnson",
                      "address" => "brianj@contoso.com"
                    }
                  },
                  "availability" => "free"
                }
              ],
              "suggestionReason" => "Suggested because it is the best time."
            },
            %{
              "confidence" => 75,
              "meetingTimeSlot" => %{
                "start" => %{
                  "dateTime" => "2026-06-15T14:00:00",
                  "timeZone" => "Pacific Standard Time"
                },
                "end" => %{
                  "dateTime" => "2026-06-15T15:00:00",
                  "timeZone" => "Pacific Standard Time"
                }
              },
              "order" => 2,
              "organizerAvailability" => "free",
              "attendeeAvailability" => [],
              "locations" => [],
              "suggestionReason" => "Alternative time."
            }
          ]
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      input = %{
        attendees: ["meganb@contoso.com", "brianj@contoso.com"],
        start_date_time: "2026-06-15T09:00:00",
        end_date_time: "2026-06-15T18:00:00",
        time_zone: "Pacific Standard Time",
        meeting_duration: "PT1H",
        return_suggestion_reasons: true
      }

      assert {:ok, %{suggestions: suggestions, empty_suggestions_reason: nil}} =
               FindMeetingTimes.run(input, context)

      assert length(suggestions) == 2

      [first, second] = suggestions
      assert first.confidence == 100
      assert first.order == 1
      assert first.meeting_time_slot["start"]["dateTime"] == "2026-06-15T10:00:00"
      assert first.organizer_availability == "free"
      assert first.suggestion_reason == "Suggested because it is the best time."
      assert length(first.locations) == 1

      assert second.confidence == 75
      assert second.order == 2
    end

    test "handles empty suggestions with reason" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          "emptySuggestionsReason" => "AttendeesUnavailable",
          "meetingTimeSuggestions" => []
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      input = %{
        attendees: ["meganb@contoso.com"],
        start_date_time: "2026-06-15T09:00:00",
        end_date_time: "2026-06-15T18:00:00"
      }

      assert {:ok, %{suggestions: [], empty_suggestions_reason: "AttendeesUnavailable"}} =
               FindMeetingTimes.run(input, context)
    end

    test "works without attendees (returns suggestions for organizer only)" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        refute Map.has_key?(decoded, "attendees")

        Req.Test.json(conn, %{
          "meetingTimeSuggestions" => [
            %{
              "confidence" => 100,
              "meetingTimeSlot" => %{
                "start" => %{"dateTime" => "2026-06-15T09:00:00", "timeZone" => "UTC"},
                "end" => %{"dateTime" => "2026-06-15T10:00:00", "timeZone" => "UTC"}
              },
              "order" => 1,
              "organizerAvailability" => "free"
            }
          ]
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      input = %{
        start_date_time: "2026-06-15T09:00:00",
        end_date_time: "2026-06-15T18:00:00"
      }

      assert {:ok, %{suggestions: [suggestion]}} = FindMeetingTimes.run(input, context)
      assert suggestion.confidence == 100
    end

    test "uses UTC timezone by default" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        [timeslot] = decoded["timeConstraint"]["timeslots"]
        assert timeslot["start"]["timeZone"] == "UTC"
        assert timeslot["end"]["timeZone"] == "UTC"

        Req.Test.json(conn, %{"meetingTimeSuggestions" => []})
      end)

      context = %{credentials: %{access_token: "test-token"}}

      input = %{
        start_date_time: "2026-06-15T09:00:00",
        end_date_time: "2026-06-15T18:00:00"
      }

      assert {:ok, %{suggestions: []}} = FindMeetingTimes.run(input, context)
    end

    test "passes minimum_attendee_percentage" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["minimumAttendeePercentage"] == 100

        Req.Test.json(conn, %{"meetingTimeSuggestions" => []})
      end)

      context = %{credentials: %{access_token: "test-token"}}

      input = %{
        start_date_time: "2026-06-15T09:00:00",
        end_date_time: "2026-06-15T18:00:00",
        minimum_attendee_percentage: 100
      }

      assert {:ok, %{suggestions: []}} = FindMeetingTimes.run(input, context)
    end

    test "returns error when access token is missing" do
      assert {:error, :missing_access_token} = FindMeetingTimes.run(%{}, %{})
    end

    test "returns error for HTTP error responses" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(500), %{
          "error" => %{"message" => "Internal server error"}
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft}} =
               FindMeetingTimes.run(%{}, context)
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
               FindMeetingTimes.run(%{}, context)
    end

    test "returns error for HTTP 400 bad request" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn |> Plug.Conn.put_status(400), %{
          "error" => %{
            "code" => "BadRequest",
            "message" => "The time window is too large."
          }
        })
      end)

      context = %{credentials: %{access_token: "test-token"}}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :microsoft, status: 400}} =
               FindMeetingTimes.run(%{}, context)
    end
  end
end
