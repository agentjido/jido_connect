defmodule Jido.Connect.Tempo.OAuthTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.Tempo.{Fixture, OAuth}

  @client_secret "client-secret-under-test"
  @opts [
    client_id: "client-under-test",
    client_secret: @client_secret,
    redirect_uri: "https://host.example.com/integrations/tempo/oauth/callback"
  ]

  # The recorder redacts both token fields, so the recorded token responses
  # are replayed with these values in their place.
  @access_token "access-token-under-test"
  @refresh_token "refresh-token-under-test"
  @recorded_scope ~w(accounts:manage accounts:view activities:produce activities:view
                     approvals:manage approvals:view audit:view papertrail:view periods:view
                     plans:manage plans:view projects:manage projects:view rates:manage
                     rates:view schemes:manage schemes:view teams:manage teams:view
                     worklogs:manage worklogs:view)

  setup {Req.Test, :verify_on_exit!}

  setup do
    previous = Application.fetch_env(:jido_connect_tempo, :tempo_oauth_req_options)

    Application.put_env(:jido_connect_tempo, :tempo_oauth_req_options,
      plug: {Req.Test, __MODULE__}
    )

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:jido_connect_tempo, :tempo_oauth_req_options, value)
        :error -> Application.delete_env(:jido_connect_tempo, :tempo_oauth_req_options)
      end
    end)
  end

  describe "authorize_url/1" do
    test "builds the encoded authorize URL" do
      url =
        OAuth.authorize_url(
          client_id: "client id/1",
          redirect_uri: "https://host.example.com/integrations/tempo/oauth/callback?x=1",
          jira_url: "https://example.atlassian.net"
        )

      assert url ==
               "https://api.tempo.io/oauth/authorize/redirect" <>
                 "?client_id=client%20id%2F1" <>
                 "&redirect_uri=https%3A%2F%2Fhost.example.com%2Fintegrations%2Ftempo%2Foauth%2Fcallback%3Fx%3D1" <>
                 "&jira_url=https%3A%2F%2Fexample.atlassian.net"
    end

    test "requires client_id, redirect_uri and jira_url" do
      valid = [
        client_id: "client",
        redirect_uri: "https://host.example.com/cb",
        jira_url: "https://example.atlassian.net"
      ]

      for key <- [:client_id, :redirect_uri, :jira_url], value <- [nil, ""] do
        opts = Keyword.put(valid, key, value)
        assert_raise Error.ConfigError, ~r/#{key}/, fn -> OAuth.authorize_url(opts) end
      end
    end
  end

  describe "exchange_code/2" do
    test "posts the form body to /oauth/token/ and keeps both tokens, expiry and scope" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert {conn.method, conn.scheme, conn.host, conn.request_path} ==
                 {"POST", :https, "api.tempo.io", "/oauth/token/"}

        assert Plug.Conn.get_req_header(conn, "content-type") == [
                 "application/x-www-form-urlencoded"
               ]

        assert URI.decode_query(Req.Test.raw_body(conn)) == %{
                 "grant_type" => "authorization_code",
                 "client_id" => "client-under-test",
                 "client_secret" => @client_secret,
                 "redirect_uri" => "https://host.example.com/integrations/tempo/oauth/callback",
                 "code" => "code-1"
               }

        Fixture.respond(conn, "oauth_exchange", body: &with_tokens/1)
      end)

      assert {:ok, token} = OAuth.exchange_code("code-1", @opts)

      assert token == %{
               access_token: @access_token,
               refresh_token: @refresh_token,
               expires_in: 2_591_999,
               scope: @recorded_scope
             }
    end

    test "rejects a token response without its tokens and does not echo the body" do
      Req.Test.expect(__MODULE__, fn conn ->
        Fixture.respond(conn, "oauth_exchange",
          body: &(&1 |> with_tokens() |> Map.delete("access_token"))
        )
      end)

      assert {:error,
              %Error.ProviderError{
                provider: :tempo,
                reason: :invalid_response,
                details: %{missing_fields: [:access_token]}
              } = error} = OAuth.exchange_code("code-1", @opts)

      refute inspect(error) =~ @refresh_token
    end

    test "an invalid code is a normalized error without client secret or code" do
      Req.Test.expect(__MODULE__, &Fixture.respond(&1, "oauth_invalid_code"))

      assert {:error,
              %Error.ProviderError{provider: :tempo, reason: :forbidden, status: 403} = error} =
               OAuth.exchange_code("code-under-test", @opts)

      assert error.details.message == "authorization code is invalid"
      refute_secrets(error, ["code-under-test"])
    end

    # The recorded rejection with the submitted code and secret put into its
    # message, as a provider echoing its input would send it.
    test "secrets echoed in an error message are redacted" do
      Req.Test.expect(__MODULE__, fn conn ->
        Fixture.respond(conn, "oauth_invalid_code",
          body: &Map.put(&1, "message", "code code-under-test for #{@client_secret} is invalid")
        )
      end)

      assert {:error, %Error.ProviderError{} = error} =
               OAuth.exchange_code("code-under-test", @opts)

      assert error.details.message == "code [redacted] for [redacted] is invalid"
      refute_secrets(error, ["code-under-test"])
    end

    # The recorded rejection with an `errors` list that names no message, so
    # the echo sits only in the top-level message.
    test "secrets echoed in a top-level message next to errors are redacted" do
      Req.Test.expect(__MODULE__, fn conn ->
        Fixture.respond(conn, "oauth_invalid_code",
          body:
            &Map.merge(&1, %{
              "errors" => [%{"code" => "x"}],
              "message" => "code code-under-test for #{@client_secret} is invalid"
            })
        )
      end)

      assert {:error, %Error.ProviderError{reason: :forbidden} = error} =
               OAuth.exchange_code("code-under-test", @opts)

      assert error.details.message == "code [redacted] for [redacted] is invalid"
      refute_secrets(error, ["code-under-test"])
    end

    # Errors keep 256 bytes of a message. A secret echoed across that cut
    # must be redacted before it, or its first bytes remain.
    test "secrets echoed at the truncation point leave no prefix" do
      for secret <- [@client_secret, "code-under-test"] do
        Req.Test.expect(__MODULE__, fn conn ->
          Fixture.respond(conn, "oauth_invalid_code",
            body: &Map.put(&1, "message", String.duplicate("x", 248) <> secret <> " is invalid")
          )
        end)

        assert {:error, %Error.ProviderError{reason: :forbidden} = error} =
                 OAuth.exchange_code("code-under-test", @opts)

        prefix = binary_part(secret, 0, 8)
        refute inspect(error) =~ prefix
        refute inspect(Error.to_map(error)) =~ prefix
      end
    end

    test "a token request does not follow redirects" do
      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "https://collector.example.com/oauth/token/")
        |> Plug.Conn.send_resp(307, "")
      end)

      assert {:error, %Error.ProviderError{reason: :redirect_not_followed, status: 307}} =
               OAuth.exchange_code("code-1", @opts)
    end

    test "Req options cannot change the token URL, add auth or enable redirects" do
      Application.put_env(:jido_connect_tempo, :tempo_oauth_req_options,
        plug: {Req.Test, __MODULE__},
        base_url: "https://collector.example.com",
        url: "https://collector.example.com/collect",
        auth: {:bearer, "injected-token"},
        redirect: true,
        redirect_trusted: true,
        follow_redirects: true,
        location_trusted: true
      )

      test_pid = self()

      Req.Test.stub(__MODULE__, fn conn ->
        authorization = Plug.Conn.get_req_header(conn, "authorization")
        send(test_pid, {:seen, conn.host, conn.request_path, authorization})

        conn
        |> Plug.Conn.put_resp_header("location", "https://collector.example.com/oauth/token/")
        |> Plug.Conn.send_resp(307, "")
      end)

      assert {:error, %Error.ProviderError{reason: :redirect_not_followed, status: 307}} =
               OAuth.exchange_code("code-1", @opts)

      assert_received {:seen, "api.tempo.io", "/oauth/token/", []}
      refute_received {:seen, _host, _path, _authorization}
    end

    # The recorded rejection, cut short and replayed as 503.
    test "a malformed JSON error body keeps its status" do
      body = "oauth_invalid_code" |> Fixture.recorded!() |> Map.fetch!("body") |> Jason.encode!()

      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(503, binary_part(body, 0, byte_size(body) - 3))
      end)

      assert {:error, %Error.ProviderError{reason: :server_error, status: 503}} =
               OAuth.exchange_code("code-1", @opts)
    end

    test "a timeout is a request error" do
      Req.Test.expect(__MODULE__, &Req.Test.transport_error(&1, :timeout))

      assert {:error, %Error.ProviderError{reason: :request_error} = error} =
               OAuth.exchange_code("code-1", @opts)

      refute_secrets(error, ["code-1"])
    end

    test "requires client_id, client_secret and redirect_uri" do
      for key <- [:client_id, :client_secret, :redirect_uri] do
        error =
          assert_raise Error.ConfigError, ~r/#{key}/, fn ->
            OAuth.exchange_code("code-1", Keyword.delete(@opts, key))
          end

        refute inspect(error) =~ @client_secret
      end
    end
  end

  describe "refresh/2" do
    test "posts the refresh form and returns both replacement tokens" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert {conn.method, conn.host, conn.request_path} ==
                 {"POST", "api.tempo.io", "/oauth/token/"}

        assert URI.decode_query(Req.Test.raw_body(conn)) == %{
                 "grant_type" => "refresh_token",
                 "client_id" => "client-under-test",
                 "client_secret" => @client_secret,
                 "redirect_uri" => "https://host.example.com/integrations/tempo/oauth/callback",
                 "refresh_token" => "stored-refresh-token"
               }

        Fixture.respond(conn, "oauth_refresh", body: &with_tokens/1)
      end)

      assert {:ok, token} = OAuth.refresh("stored-refresh-token", @opts)

      assert token == %{
               access_token: @access_token,
               refresh_token: @refresh_token,
               expires_in: 2_591_999,
               scope: @recorded_scope
             }
    end

    # Tempo invalidates the old refresh token on every refresh, so a response
    # without a new one leaves the connection without a usable refresh token.
    test "a refresh response without a new refresh token is an error" do
      Req.Test.expect(__MODULE__, fn conn ->
        Fixture.respond(conn, "oauth_refresh",
          body: &(&1 |> with_tokens() |> Map.delete("refresh_token"))
        )
      end)

      assert {:error,
              %Error.ProviderError{
                reason: :invalid_response,
                details: %{missing_fields: [:refresh_token]}
              } = error} = OAuth.refresh("stored-refresh-token", @opts)

      refute inspect(error) =~ @access_token
    end

    # Once Tempo answers with both tokens it has rotated the pair, so an
    # unusable expiry must not discard them.
    test "a refresh response without a usable expires_in keeps both tokens" do
      for expires_in <- [:absent, "2591999", 0] do
        Req.Test.expect(__MODULE__, fn conn ->
          Fixture.respond(conn, "oauth_refresh",
            body: &(&1 |> with_tokens() |> put_field("expires_in", expires_in))
          )
        end)

        assert {:ok,
                %{access_token: @access_token, refresh_token: @refresh_token, expires_in: nil}} =
                 OAuth.refresh("stored-refresh-token", @opts)
      end
    end

    # A missing scope tells nothing about the grant; an empty one grants none.
    test "a refresh response without a scope string has scope nil, an empty one an empty list" do
      for scope <- [:absent, nil, 42] do
        Req.Test.expect(__MODULE__, fn conn ->
          Fixture.respond(conn, "oauth_refresh",
            body: &(&1 |> with_tokens() |> put_field("scope", scope))
          )
        end)

        assert {:ok, %{refresh_token: @refresh_token, scope: nil}} =
                 OAuth.refresh("stored-refresh-token", @opts)
      end

      Req.Test.expect(__MODULE__, fn conn ->
        Fixture.respond(conn, "oauth_refresh",
          body: &(&1 |> with_tokens() |> Map.put("scope", ""))
        )
      end)

      assert {:ok, %{scope: []}} = OAuth.refresh("stored-refresh-token", @opts)
    end

    # The recorded refresh response wrapped in a JSON array.
    test "a refresh response that is not a JSON object is an invalid response" do
      Req.Test.expect(__MODULE__, fn conn ->
        Fixture.respond(conn, "oauth_refresh", body: &[with_tokens(&1)])
      end)

      assert {:error,
              %Error.ProviderError{provider: :tempo, reason: :invalid_response, status: 200} =
                error} = OAuth.refresh("stored-refresh-token", @opts)

      refute inspect(error) =~ @refresh_token
      refute_secrets(error, ["stored-refresh-token"])
    end

    test "an invalid refresh token is a normalized error without the token" do
      Req.Test.expect(__MODULE__, &Fixture.respond(&1, "oauth_invalid_refresh_token"))

      assert {:error, %Error.ProviderError{reason: :forbidden, status: 403} = error} =
               OAuth.refresh("stored-refresh-token", @opts)

      assert error.details.message == "refresh token is invalid"
      refute_secrets(error, ["stored-refresh-token"])
    end
  end

  # The live smoke recorder appends its response step when it runs as the
  # adapter; it must see the decoded body to redact the token fields.
  test "a response step an adapter appends sees the decoded token body" do
    Application.put_env(:jido_connect_tempo, :tempo_oauth_req_options,
      adapter: Jido.Connect.Tempo.LateStepAdapter
    )

    assert {:ok, _token} = OAuth.exchange_code("code-1", @opts)
    assert_received {:late_step_body, %{"access_token" => _, "refresh_token" => _}}

    assert {:ok, _token} = OAuth.refresh("stored-refresh-token", @opts)
    assert_received {:late_step_body, %{"access_token" => _, "refresh_token" => _}}
  end

  defp with_tokens(body),
    do: Map.merge(body, %{"access_token" => @access_token, "refresh_token" => @refresh_token})

  defp put_field(body, key, :absent), do: Map.delete(body, key)
  defp put_field(body, key, value), do: Map.put(body, key, value)

  defp refute_secrets(error, values) do
    for value <- [@client_secret | values] do
      refute inspect(error) =~ value
      refute inspect(Error.to_map(error)) =~ value
    end
  end
end
