defmodule Jido.Connect.Calcom.ClientTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Calcom
  alias Jido.Connect.Calcom.Client
  alias Jido.Connect.Calcom.Client.{Response, Transport}
  alias Jido.Connect.Error

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_calcom, :calcom_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_calcom, :calcom_req_options)
      Application.delete_env(:jido_connect_calcom, :calcom_api_base_url)
    end)
  end

  test "transport builds bearer requests with configurable base URL and API version" do
    Application.put_env(:jido_connect_calcom, :calcom_api_base_url, "https://cal.test")

    request = Transport.api_request("cal_test_key", cal_api_version: "2024-06-14")

    assert Transport.base_url() == "https://cal.test"
    assert Transport.api_version(:event_types) == "2024-06-14"
    assert Transport.api_version(:bookings_list) == "2026-05-01"
    assert Transport.api_version(:bookings_detail) == "2026-02-25"
    assert Transport.api_version(:webhooks) == "2024-06-14"
    assert request.options.base_url == "https://cal.test"
    assert request.headers["authorization"] == ["Bearer cal_test_key"]
    assert request.headers["accept"] == ["application/json"]
    assert request.headers["cal-api-version"] == ["2024-06-14"]
  end

  test "transport handles defaults and Cal.com error shapes" do
    Application.delete_env(:jido_connect_calcom, :calcom_api_base_url)

    request = Transport.api_request("cal_test_key")

    assert Transport.base_url() == "https://api.cal.com"
    assert request.options.base_url == "https://api.cal.com"
    refute Map.has_key?(request.headers, "cal-api-version")

    assert {:error,
            %Error.ProviderError{
              provider: :calcom,
              reason: :http_error,
              status: 400,
              details: %{message: "Bad request"}
            }} =
             Transport.handle_error_response(
               {:ok, %{status: 400, body: %{"message" => "Bad request"}}}
             )

    assert {:error, %Error.ProviderError{provider: :calcom}} =
             Transport.handle_error_response({:error, %RuntimeError{message: "network down"}})
  end

  test "list event types sends expected request and normalizes results" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/event-types"
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")
      assert ["2024-06-14"] = Plug.Conn.get_req_header(conn, "cal-api-version")

      assert %{
               "eventSlug" => "intro",
               "orgId" => "42",
               "orgSlug" => "acme",
               "username" => "mike"
             } = URI.decode_query(conn.query_string)

      Req.Test.json(conn, %{
        data: [
          %{
            id: 10,
            slug: "intro",
            title: "Intro",
            length: 30
          }
        ]
      })
    end)

    assert {:ok, [%Calcom.EventType{id: 10, slug: "intro", title: "Intro"}]} =
             Client.list_event_types(
               %{username: "mike", event_slug: "intro", org_slug: "acme", org_id: 42},
               "token"
             )
  end

  test "list bookings sends expected request and normalizes pagination" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/bookings"
      assert ["2026-05-01"] = Plug.Conn.get_req_header(conn, "cal-api-version")

      assert %{
               "afterStart" => "2026-06-01T00:00:00Z",
               "attendeeEmail" => "person@example.com",
               "beforeEnd" => "2026-06-30T00:00:00Z",
               "cursor" => "cursor-1",
               "eventTypeId" => "10",
               "limit" => "25",
               "status" => "upcoming"
             } = URI.decode_query(conn.query_string)

      Req.Test.json(conn, %{
        data: [%{uid: "booking-1", title: "Intro"}],
        pagination: %{nextCursor: "cursor-2", hasMore: true}
      })
    end)

    assert {:ok, %{bookings: [%Calcom.Booking{uid: "booking-1"}], next_cursor: "cursor-2"}} =
             Client.list_bookings(
               %{
                 status: "upcoming",
                 attendee_email: "person@example.com",
                 event_type_id: 10,
                 after_start: "2026-06-01T00:00:00Z",
                 before_end: "2026-06-30T00:00:00Z",
                 cursor: "cursor-1",
                 limit: 25
               },
               "token"
             )
  end

  test "get booking sends expected request and normalizes data envelope" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/bookings/booking-1"
      assert ["2026-02-25"] = Plug.Conn.get_req_header(conn, "cal-api-version")

      Req.Test.json(conn, %{data: %{uid: "booking-1", title: "Intro"}})
    end)

    assert {:ok, %Calcom.Booking{uid: "booking-1", title: "Intro"}} =
             Client.get_booking(%{booking_uid: "booking-1"}, "token")
  end

  test "cancel booking sends expected body and normalizes booking" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v2/bookings/booking-1/cancel"
      assert ["2026-02-25"] = Plug.Conn.get_req_header(conn, "cal-api-version")

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"cancellationReason" => "conflict"}

      Req.Test.json(conn, %{data: %{uid: "booking-1", status: "cancelled"}})
    end)

    assert {:ok, %Calcom.Booking{uid: "booking-1", status: "cancelled"}} =
             Client.cancel_booking(
               %{booking_uid: "booking-1", body: %{"cancellationReason" => "conflict"}},
               "token"
             )
  end

  test "reschedule booking sends expected body and normalizes booking" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v2/bookings/booking-1/reschedule"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"start" => "2026-06-01T10:00:00Z"}

      Req.Test.json(conn, %{data: %{uid: "booking-1", startTime: "2026-06-01T10:00:00Z"}})
    end)

    assert {:ok, %Calcom.Booking{uid: "booking-1", start: "2026-06-01T10:00:00Z"}} =
             Client.reschedule_booking(
               %{booking_uid: "booking-1", body: %{"start" => "2026-06-01T10:00:00Z"}},
               "token"
             )
  end

  test "response helpers normalize successful payloads" do
    assert {:ok, [%Calcom.EventType{id: 10}]} =
             Response.handle_event_types_response(
               {:ok, %{status: 200, body: %{"data" => [%{"id" => 10}]}}}
             )

    assert {:ok, %{bookings: [%Calcom.Booking{uid: "booking-1"}]}} =
             Response.handle_list_bookings_response(
               {:ok, %{status: 200, body: %{"data" => [%{"uid" => "booking-1"}]}}}
             )

    assert {:ok, %Calcom.Booking{uid: "booking-1"}} =
             Response.handle_get_booking_response(
               {:ok, %{status: 200, body: %{"data" => %{"uid" => "booking-1"}}}}
             )

    assert {:ok, %Calcom.Booking{uid: "booking-1"}} =
             Response.handle_cancel_booking_response(
               {:ok, %{status: 200, body: %{"uid" => "booking-1"}}}
             )

    assert {:ok, %Calcom.Booking{uid: "booking-1"}} =
             Response.handle_reschedule_booking_response(
               {:ok, %{status: 200, body: %{"data" => %{"uid" => "booking-1"}}}}
             )
  end

  test "response helpers normalize malformed successes and provider errors" do
    assert {:error,
            %Error.ProviderError{
              provider: :calcom,
              reason: :invalid_response,
              details: %{body_summary: %{type: :list, length: 0}}
            }} =
             Response.handle_event_types_response({:ok, %{status: 200, body: []}})

    assert {:error,
            %Error.ProviderError{
              provider: :calcom,
              reason: :invalid_response,
              details: %{body_summary: %{type: :map, keys: ["data"]}}
            }} =
             Response.handle_event_types_response({:ok, %{status: 200, body: %{"data" => [%{}]}}})

    assert {:error, %Error.ProviderError{reason: :invalid_response}} =
             Response.handle_list_bookings_response({:ok, %{status: 200, body: []}})

    assert {:error, %Error.ProviderError{reason: :invalid_response}} =
             Response.handle_get_booking_response({:ok, %{status: 200, body: []}})

    assert {:error, %Error.ProviderError{reason: :invalid_response}} =
             Response.handle_cancel_booking_response({:ok, %{status: 200, body: []}})

    assert {:error, %Error.ProviderError{reason: :invalid_response}} =
             Response.handle_reschedule_booking_response({:ok, %{status: 200, body: []}})

    assert {:error, %Error.ProviderError{reason: :invalid_response}} =
             Response.handle_create_webhook_response({:ok, %{status: 200, body: []}})

    assert {:error, %Error.ProviderError{reason: :invalid_response}} =
             Response.handle_list_webhooks_response({:ok, %{status: 200, body: []}})

    assert {:error, %Error.ProviderError{reason: :invalid_response}} =
             Response.handle_delete_webhook_response({:ok, %{status: 200, body: []}})

    assert {:error,
            %Error.ProviderError{
              provider: :calcom,
              reason: :http_error,
              status: 401,
              details: %{message: "Unauthorized"}
            }} =
             Response.handle_list_bookings_response(
               {:ok, %{status: 401, body: %{"error" => %{"message" => "Unauthorized"}}}}
             )

    assert {:error, %Error.ProviderError{provider: :calcom, status: 429}} =
             Response.handle_get_booking_response(
               {:ok, %{status: 429, body: %{"message" => "Rate limited"}}}
             )

    assert {:error, %Error.ProviderError{provider: :calcom}} =
             Response.handle_cancel_booking_response({:error, %RuntimeError{message: "timeout"}})

    assert {:error, %Error.ProviderError{provider: :calcom}} =
             Response.handle_reschedule_booking_response(
               {:error, %RuntimeError{message: "timeout"}}
             )

    assert {:error, %Error.ProviderError{provider: :calcom}} =
             Response.handle_create_webhook_response({:error, %RuntimeError{message: "timeout"}})

    assert {:error, %Error.ProviderError{provider: :calcom}} =
             Response.handle_list_webhooks_response({:error, %RuntimeError{message: "timeout"}})

    assert {:error, %Error.ProviderError{provider: :calcom}} =
             Response.handle_delete_webhook_response({:error, %RuntimeError{message: "timeout"}})
  end

  test "create webhook sends expected body and normalizes webhook" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/v2/webhooks"
      assert ["2024-06-14"] = Plug.Conn.get_req_header(conn, "cal-api-version")

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert Jason.decode!(body) == %{
               "subscriberUrl" => "https://example.com/hook",
               "triggers" => ["BOOKING_CREATED"],
               "active" => true
             }

      Req.Test.json(conn, %{
        data: %{
          id: 1,
          subscriberUrl: "https://example.com/hook",
          active: true,
          triggers: ["BOOKING_CREATED"]
        }
      })
    end)

    assert {:ok, %Calcom.Webhook{id: 1, subscriber_url: "https://example.com/hook", active: true}} =
             Client.create_webhook(
               %{
                 subscriber_url: "https://example.com/hook",
                 triggers: ["BOOKING_CREATED"],
                 active: true
               },
               "token"
             )
  end

  test "list webhooks sends expected request and normalizes results" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/v2/webhooks"
      assert ["2024-06-14"] = Plug.Conn.get_req_header(conn, "cal-api-version")

      assert %{"eventTypeId" => "10"} = URI.decode_query(conn.query_string)

      Req.Test.json(conn, %{
        data: [
          %{id: 1, subscriberUrl: "https://example.com/hook", triggers: ["BOOKING_CREATED"]}
        ]
      })
    end)

    assert {:ok, [%Calcom.Webhook{id: 1, subscriber_url: "https://example.com/hook"}]} =
             Client.list_webhooks(%{event_type_id: 10}, "token")
  end

  test "delete webhook sends expected request and normalizes response" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/v2/webhooks/42"
      assert ["2024-06-14"] = Plug.Conn.get_req_header(conn, "cal-api-version")

      Req.Test.json(conn, %{data: %{id: 42}})
    end)

    assert {:ok, %Calcom.Webhook{id: 42}} =
             Client.delete_webhook(%{webhook_id: 42}, "token")
  end

  test "webhook response helpers normalize successful payloads" do
    assert {:ok, %Calcom.Webhook{id: 1}} =
             Response.handle_create_webhook_response(
               {:ok, %{status: 200, body: %{"data" => %{"id" => 1}}}}
             )

    assert {:ok, [%Calcom.Webhook{id: 1}]} =
             Response.handle_list_webhooks_response(
               {:ok, %{status: 200, body: %{"data" => [%{"id" => 1}]}}}
             )

    assert {:ok, %Calcom.Webhook{id: 1}} =
             Response.handle_delete_webhook_response(
               {:ok, %{status: 200, body: %{"data" => %{"id" => 1}}}}
             )
  end
end
