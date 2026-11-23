defmodule Jido.Connect.Tempo.Client.TransportTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.{Connection, Error}
  alias Jido.Connect.Tempo.Client.{Request, Transport}
  alias Jido.Connect.Tempo.Fixture

  @october [params: [from: "2026-10-01", to: "2026-10-31"]]

  setup {Req.Test, :verify_on_exit!}

  setup do
    put_req_options(plug: {Req.Test, __MODULE__})
  end

  test "sends the API token as a Bearer credential" do
    request = request!(:api_token, "https://api.us.tempo.io", "api-token-a")

    Req.Test.expect(__MODULE__, fn conn ->
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer api-token-a"]
      assert Plug.Conn.get_req_header(conn, "accept") == ["application/json"]
      assert conn.request_path == "/4/periods"
      assert conn.query_string == "from=2026-10-01&to=2026-10-31"
      Fixture.respond(conn, "periods")
    end)

    assert {:ok, %{"periods" => [%{"from" => "2026-10-01", "to" => "2026-10-31"}]}} =
             Transport.get(request, "/4/periods", @october)
  end

  test "sends the OAuth access token as a Bearer credential" do
    request = request!(:oauth2_user, "https://api.us.tempo.io", "oauth-token-a")

    Req.Test.expect(__MODULE__, fn conn ->
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer oauth-token-a"]
      Fixture.respond(conn, "periods")
    end)

    assert {:ok, %{"periods" => [_period]}} = Transport.get(request, "/4/periods", @october)
  end

  test "sends each request to the exact origin of its connection" do
    for {origin, host} <- [
          {"https://api.tempo.io", "api.tempo.io"},
          {"https://api.eu.tempo.io", "api.eu.tempo.io"},
          {"https://api.us.tempo.io", "api.us.tempo.io"}
        ] do
      Req.Test.expect(__MODULE__, fn conn ->
        assert {conn.scheme, conn.host, conn.port} == {:https, host, 443}
        Fixture.respond(conn, "periods")
      end)

      assert {:ok, _body} = Transport.get(request!(:api_token, origin, "tok"), "/4/periods")
    end
  end

  test "two connections keep their own token and origin" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, {:seen, conn.host, Plug.Conn.get_req_header(conn, "authorization")})
      Fixture.respond(conn, "periods")
    end)

    [
      request!(:api_token, "https://api.eu.tempo.io", "token-eu"),
      request!(:oauth2_user, "https://api.us.tempo.io", "token-us")
    ]
    |> Task.async_stream(&Transport.get(&1, "/4/periods", @october), ordered: false)
    |> Enum.each(fn result -> assert {:ok, {:ok, _body}} = result end)

    assert_received {:seen, "api.eu.tempo.io", ["Bearer token-eu"]}
    assert_received {:seen, "api.us.tempo.io", ["Bearer token-us"]}
    refute_received {:seen, _host, _authorization}
  end

  test "a redirect to a foreign origin is not followed, so the token stays at the origin" do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, {:seen, conn.host, Plug.Conn.get_req_header(conn, "authorization")})

      conn
      |> Plug.Conn.put_resp_header("location", "https://collector.example.com/4/periods")
      |> Plug.Conn.send_resp(302, "")
    end)

    request = request!(:api_token, "https://api.us.tempo.io", "token-a")

    assert {:error,
            %Error.ProviderError{provider: :tempo, status: 302, reason: :redirect_not_followed}} =
             Transport.get(request, "/4/periods")

    assert_received {:seen, "api.us.tempo.io", ["Bearer token-a"]}
    refute_received {:seen, "collector.example.com", _authorization}
  end

  test "Req options cannot change the origin, replace the token or enable redirects" do
    put_req_options(
      plug: {Req.Test, __MODULE__},
      base_url: "https://collector.example.com",
      auth: {:bearer, "injected-token"},
      redirect: true,
      redirect_trusted: true,
      follow_redirects: true,
      location_trusted: true
    )

    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, {:seen, conn.host, Plug.Conn.get_req_header(conn, "authorization")})

      conn
      |> Plug.Conn.put_resp_header("location", "https://collector.example.com/4/periods")
      |> Plug.Conn.send_resp(302, "")
    end)

    assert {:error, %Error.ProviderError{status: 302}} =
             Transport.get(request!(:api_token, "https://api.eu.tempo.io", "tok"), "/4/periods")

    assert_received {:seen, "api.eu.tempo.io", ["Bearer tok"]}
    refute_received {:seen, _host, _authorization}
  end

  test "a request to any other origin fails before it is sent" do
    test_pid = self()
    Req.Test.stub(__MODULE__, fn conn -> send(test_pid, {:seen, conn.host}) end)
    request = request!(:api_token, "https://api.us.tempo.io", "tok")

    for url <- [
          "https://collector.example.com/4/periods",
          "http://api.us.tempo.io/4/periods",
          "https://api.us.tempo.io:8443/4/periods",
          "https://api.tempo.io/4/periods"
        ] do
      assert {:error,
              %Error.ProviderError{
                provider: :tempo,
                reason: :request_error,
                delivery: :not_sent,
                details: %{reason: :foreign_origin}
              }} = Transport.get(request, url)

      assert {:error, %Transport.OriginError{}} = Req.get(Transport.request(request), url: url)
    end

    refute_received {:seen, _host}
  end

  # The live smoke recorder appends its response step when it runs as the
  # adapter; it must see the decoded body to sanitize keys such as accountId.
  test "a response step an adapter appends sees the decoded JSON body" do
    put_req_options(adapter: Jido.Connect.Tempo.LateStepAdapter)
    request = request!(:api_token, "https://api.us.tempo.io", "tok")

    assert {:ok, %{"periods" => [_period]}} = Transport.get(request, "/4/periods", @october)
    assert_received {:late_step_body, %{"periods" => [_period]}}
  end

  defp put_req_options(options) do
    previous = Application.fetch_env(:jido_connect_tempo, :tempo_req_options)
    Application.put_env(:jido_connect_tempo, :tempo_req_options, options)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:jido_connect_tempo, :tempo_req_options, value)
        :error -> Application.delete_env(:jido_connect_tempo, :tempo_req_options)
      end
    end)
  end

  defp request!(profile, origin, token) do
    field = if profile == :api_token, do: :api_token, else: :access_token

    connection =
      Connection.new!(%{
        id: "tempo_#{profile}_#{origin}",
        provider: :tempo,
        profile: profile,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        subject: %{account_id: "712020:acct-a"},
        status: :connected,
        metadata: %{api_origin: origin}
      })

    {:ok, request} = Request.new(connection, %{field => token})
    request
  end
end
