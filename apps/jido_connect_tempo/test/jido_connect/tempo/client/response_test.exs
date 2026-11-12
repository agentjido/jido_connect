defmodule Jido.Connect.Tempo.Client.ResponseTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.{Connection, Error}
  alias Jido.Connect.Tempo.Client.{Request, Transport}
  alias Jido.Connect.Tempo.Fixture

  @token "tempo-token-under-test"

  setup {Req.Test, :verify_on_exit!}

  setup do
    previous = Application.fetch_env(:jido_connect_tempo, :tempo_req_options)
    Application.put_env(:jido_connect_tempo, :tempo_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:jido_connect_tempo, :tempo_req_options, value)
        :error -> Application.delete_env(:jido_connect_tempo, :tempo_req_options)
      end
    end)
  end

  test "400 keeps Tempo's error message" do
    assert {:error, %Error.ProviderError{reason: :bad_request, status: 400} = error} =
             get_with(&Fixture.respond(&1, "bad_request"))

    assert error.details.message == "Non valid date 'not-a-date': format must be yyyy-MM-dd"
    assert error.delivery == :rejected
    refute_token(error)
  end

  test "401 without a body is an auth failure without the token" do
    for fixture <- ["unauthorized", "wrong_cluster"] do
      assert {:error,
              %Error.ProviderError{provider: :tempo, reason: :unauthorized, status: 401} = error} =
               get_with(&Fixture.respond(&1, fixture))

      assert error.details.message == "provider returned 0 byte body"
      refute Error.retryable?(error)
      refute_token(error)
    end
  end

  test "403 keeps Tempo's error message" do
    assert {:error, %Error.ProviderError{reason: :forbidden, status: 403} = error} =
             get_with(&Fixture.respond(&1, "forbidden"))

    assert error.details.message == "You do not have permission to access Holiday Schemes"
  end

  test "404 with a JSON body and with an HTML body" do
    assert {:error, %Error.ProviderError{reason: :not_found, status: 404} = error} =
             get_with(&Fixture.respond(&1, "not_found"))

    assert error.details.message == "Worklog cannot be found"

    assert {:error, %Error.ProviderError{reason: :not_found, status: 404} = error} =
             get_with(&Fixture.respond(&1, "not_found_html"))

    assert error.details.message == "provider returned 10 byte body"
    assert error.details.body_summary == %{type: :binary, bytes: 10}
    refute inspect(error) =~ "Not found\\n"
  end

  # Tempo's 429 cannot be triggered safely; the recorded 403 error body is
  # replayed with status 429 and a Retry-After header.
  test "429 carries retry_after and is retryable" do
    assert {:error, %Error.ProviderError{reason: :rate_limited, status: 429} = error} =
             get_with(
               &Fixture.respond(&1, "forbidden", status: 429, headers: [{"retry-after", "30"}])
             )

    assert error.details.retry_after == 30
    assert Error.retryable?(error)
    assert Error.to_map(error).retry_guidance == :safe_to_retry
  end

  # A 5xx cannot be triggered safely; the recorded 400 error body is replayed
  # with status 503.
  test "5xx is a retryable server error" do
    assert {:error, %Error.ProviderError{reason: :server_error, status: 503} = error} =
             get_with(&Fixture.respond(&1, "bad_request", status: 503))

    assert error.details.retry_after == nil
    assert Error.retryable?(error)
  end

  # Statuses without a reason of their own, replayed with the recorded 400
  # body.
  test "another error status is an http error with Tempo's message" do
    for status <- [409, 410, 422] do
      assert {:error, %Error.ProviderError{reason: :http_error, status: ^status} = error} =
               get_with(&Fixture.respond(&1, "bad_request", status: status))

      assert error.details.message == "Non valid date 'not-a-date': format must be yyyy-MM-dd"
    end
  end

  # The recorded 400 body with a second error, and with an error that has
  # no message.
  test "several Tempo messages are joined and an error without one is skipped" do
    errors = [
      %{"message" => "Non valid date 'not-a-date': format must be yyyy-MM-dd"},
      %{"code" => "x"},
      %{"message" => "to must not be before from"}
    ]

    assert {:error, %Error.ProviderError{reason: :bad_request} = error} =
             get_with(fn conn ->
               Fixture.respond(conn, "bad_request", body: &Map.put(&1, "errors", errors))
             end)

    assert error.details.message ==
             "Non valid date 'not-a-date': format must be yyyy-MM-dd; to must not be before from"

    assert {:error, %Error.ProviderError{reason: :bad_request} = error} =
             get_with(fn conn ->
               Fixture.respond(conn, "bad_request",
                 body: &Map.put(&1, "errors", [%{"code" => "x"}])
               )
             end)

    assert error.details.message == "provider returned an error response"
  end

  # The recorded text/html 404 body, replayed with status 200.
  test "a successful response without a JSON body is an invalid response" do
    assert {:error, %Error.ProviderError{reason: :invalid_response, status: 200} = error} =
             get_with(&Fixture.respond(&1, "not_found_html", status: 200))

    assert error.message == "Tempo API response was not JSON"
    assert error.details.body_summary == %{type: :binary, bytes: 10}
  end

  # The recorded periods body, cut short, under its recorded JSON content type.
  test "a malformed JSON body is an invalid response" do
    body = "periods" |> Fixture.recorded!() |> Map.fetch!("body") |> Jason.encode!()
    truncated = binary_part(body, 0, byte_size(body) - 3)

    assert {:error, %Error.ProviderError{reason: :invalid_response, status: 200} = error} =
             get_with(fn conn ->
               conn
               |> Plug.Conn.put_resp_content_type("application/json")
               |> Plug.Conn.send_resp(200, truncated)
             end)

    assert error.message == "Tempo API response was not valid JSON"
    refute inspect(error) =~ "2026-10-01"
  end

  # The recorded 403 error body, cut short and replayed as 429 with a
  # Retry-After header.
  test "a malformed JSON error body keeps the status and Retry-After" do
    body = "forbidden" |> Fixture.recorded!() |> Map.fetch!("body") |> Jason.encode!()
    truncated = binary_part(body, 0, byte_size(body) - 3)

    assert {:error, %Error.ProviderError{reason: :rate_limited, status: 429} = error} =
             get_with(fn conn ->
               conn
               |> Plug.Conn.put_resp_content_type("application/json")
               |> Plug.Conn.put_resp_header("retry-after", "30")
               |> Plug.Conn.send_resp(429, truncated)
             end)

    assert error.details.retry_after == 30
    assert error.details.message == "provider returned #{byte_size(truncated)} byte body"
    assert Error.to_map(error).retry_guidance == :safe_to_retry
    refute inspect(error) =~ "Holiday Schemes"
  end

  test "a timeout is a request error" do
    assert {:error, %Error.ProviderError{reason: :request_error, status: nil} = error} =
             get_with(&Req.Test.transport_error(&1, :timeout))

    assert error.details.reason == :timeout
    assert error.delivery == :sent_outcome_unknown
    refute_token(error)
  end

  defp get_with(plug) do
    Req.Test.expect(__MODULE__, plug)

    connection =
      Connection.new!(%{
        id: "tempo_conn_1",
        provider: :tempo,
        profile: :api_token,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        subject: %{account_id: "712020:acct-a"},
        status: :connected,
        metadata: %{api_origin: "https://api.us.tempo.io"}
      })

    {:ok, request} = Request.new(connection, %{api_token: @token})
    Transport.get(request, "/4/periods")
  end

  defp refute_token(error) do
    refute inspect(error) =~ @token
    refute inspect(Error.to_map(error)) =~ @token
  end
end
