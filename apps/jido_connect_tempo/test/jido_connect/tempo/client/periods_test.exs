defmodule Jido.Connect.Tempo.Client.PeriodsTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.{Connection, Error}
  alias Jido.Connect.Tempo.{Client, Fixture}
  alias Jido.Connect.Tempo.Client.Request

  # `periods` is the recorded answer of `GET /4/periods` for October 2026:
  # one monthly period.

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

  describe "list_periods/2" do
    test "reads the periods of the inclusive range with a GET" do
      test_pid = self()

      Req.Test.expect(__MODULE__, fn conn ->
        send(test_pid, {:request, conn.method, conn.request_path, conn.query_string})
        Fixture.respond(conn, "periods")
      end)

      assert {:ok, [%{from: "2026-10-01", to: "2026-10-31"}]} =
               Client.list_periods(request(), from: "2026-10-01", to: "2026-10-31")

      assert_received {:request, "GET", "/4/periods", query}
      assert URI.decode_query(query) == %{"from" => "2026-10-01", "to" => "2026-10-31"}
    end

    test "an invalid or reversed range fails before any request" do
      test_pid = self()

      Req.Test.stub(__MODULE__, fn conn ->
        send(test_pid, :requested)
        Fixture.respond(conn, "periods")
      end)

      for {opts, field} <- [
            {[from: "2026-10-32", to: "2026-10-31"], :from},
            {[from: "2026-10-01T00:00:00Z", to: "2026-10-31"], :from},
            {[to: "2026-10-31"], :from},
            {[from: "2026-10-01", to: "31.10.2026"], :to},
            {[from: "2026-10-02", to: "2026-10-01"], :to}
          ] do
        assert {:error,
                %Error.ValidationError{reason: :invalid_date_range, details: %{field: ^field}}} =
                 Client.list_periods(request(), opts)
      end

      refute_received :requested
    end

    # The recorded answer with its list or one period broken.
    test "a malformed answer fails with :invalid_periods" do
      for change <- [
            &Map.delete(&1, "periods"),
            &Map.put(&1, "periods", %{}),
            &Map.put(&1, "periods", ["2026-10-01"]),
            &put_in(&1, ["periods"], [%{"from" => "2026-10-01"}]),
            &put_in(&1, ["periods"], [%{"from" => "2026-10-01", "to" => "2026-10-32"}]),
            &put_in(&1, ["periods"], [%{"from" => "2026-10-31", "to" => "2026-10-01"}])
          ] do
        Req.Test.expect(__MODULE__, &Fixture.respond(&1, "periods", body: change))

        assert {:error,
                %Error.ProviderError{
                  provider: :tempo,
                  reason: :invalid_periods,
                  delivery: :response_received
                }} = Client.list_periods(request(), from: "2026-10-01", to: "2026-10-31")
      end
    end

    test "a failed read returns the normalized error" do
      Req.Test.expect(__MODULE__, &Fixture.respond(&1, "periods", status: 503))

      assert {:error, %Error.ProviderError{reason: :server_error, status: 503}} =
               Client.list_periods(request(), from: "2026-10-01", to: "2026-10-31")
    end
  end

  defp request do
    connection =
      Connection.new!(%{
        id: "tempo_conn_1",
        provider: :tempo,
        profile: :api_token,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        subject: %{account_id: "account-1"},
        status: :connected,
        scopes: ["tempo.periods.read"],
        metadata: %{api_origin: "https://api.us.tempo.io"}
      })

    {:ok, request} = Request.new(connection, %{api_token: "tempo-api-token-274"})
    request
  end
end
