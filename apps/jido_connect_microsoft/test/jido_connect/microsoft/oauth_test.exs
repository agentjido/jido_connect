defmodule Jido.Connect.Microsoft.OAuthTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.{CredentialLease, Error}
  alias Jido.Connect.Microsoft.{Connections, OAuth}

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_microsoft, :microsoft_oauth_req_options,
      plug: {Req.Test, __MODULE__}
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_microsoft, :microsoft_oauth_req_options)
    end)
  end

  test "builds authorize URL" do
    url =
      OAuth.authorize_url(
        client_id: "client",
        redirect_uri: "https://demo.test/integrations/microsoft/oauth/callback",
        scope: ["openid", "email", "profile", "offline_access"],
        state: "state",
        prompt: "consent"
      )

    uri = URI.parse(url)
    params = URI.decode_query(uri.query)

    assert uri.scheme == "https"
    assert uri.host == "login.microsoftonline.com"
    assert uri.path == "/common/oauth2/v2.0/authorize"
    assert params["client_id"] == "client"
    assert params["prompt"] == "consent"
    assert params["redirect_uri"] == "https://demo.test/integrations/microsoft/oauth/callback"
    assert params["response_type"] == "code"
    assert params["scope"] == "openid email profile offline_access"
    assert params["state"] == "state"
  end

  test "exchanges code and refreshes tokens" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"

      Req.Test.json(conn, %{
        access_token: "access",
        refresh_token: "refresh",
        token_type: "Bearer",
        expires_in: 3600,
        scope: "openid email profile offline_access"
      })
    end)

    assert {:ok, token} =
             OAuth.exchange_code("code",
               client_id: "client",
               client_secret: "secret",
               token_url: "https://oauth.test/token",
               redirect_uri: "https://demo.test/callback"
             )

    assert token.access_token == "access"
    assert token.refresh_token == "refresh"
    assert token.scope == ["openid", "email", "profile", "offline_access"]
    assert %DateTime{} = token.expires_at

    assert {:ok, refreshed} =
             OAuth.refresh_token("refresh",
               client_id: "client",
               client_secret: "secret",
               token_url: "https://oauth.test/token"
             )

    assert refreshed.access_token == "access"
  end

  test "returns OAuth provider errors" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        error: "invalid_grant",
        error_description: "Bad authorization code."
      })
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :microsoft,
              reason: "invalid_grant",
              details: %{description: "Bad authorization code."}
            }} =
             OAuth.exchange_code("bad",
               client_id: "client",
               client_secret: "secret",
               token_url: "https://oauth.test/token"
             )
  end

  test "returns non-success OAuth HTTP errors" do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(500)
      |> Req.Test.json(%{"error_description" => "token service unavailable"})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :microsoft,
              reason: :http_error,
              status: 500,
              details: %{message: "token service unavailable"}
            }} =
             OAuth.refresh_token("refresh",
               client_id: "client",
               client_secret: "secret",
               token_url: "https://oauth.test/token"
             )
  end

  test "rejects malformed successful token responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{"scope" => "openid email"})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :microsoft,
              reason: :invalid_response,
              details: %{body_summary: %{type: :map, keys: ["scope"]}}
            }} =
             OAuth.exchange_code("code",
               client_id: "client",
               client_secret: "secret",
               token_url: "https://oauth.test/token"
             )
  end

  test "builds credential leases from token responses" do
    {:ok, connection} =
      Connections.user_connection(
        %{"id" => "aaa-bbb", "mail" => "user@example.com"},
        tenant_id: "tenant_1",
        scopes: ["openid", "email", "profile", "offline_access"]
      )

    issued_at = ~U[2026-01-01 00:00:00Z]

    assert {:ok, %CredentialLease{} = lease} =
             OAuth.credential_lease(
               connection,
               %{
                 "access_token" => "access",
                 "token_type" => "Bearer",
                 "expires_in" => 3600,
                 "scope" => "openid email"
               },
               issued_at: issued_at
             )

    assert lease.connection_id == connection.id
    assert lease.provider == :microsoft
    assert lease.profile == :user
    assert lease.fields == %{access_token: "access"}
    assert lease.scopes == ["openid", "email"]
    assert lease.expires_at == ~U[2026-01-01 01:00:00Z]
    assert lease.metadata.credential_mode == :microsoft_oauth_access_token
  end

  test "credential leases validate access tokens and use caller overrides" do
    {:ok, connection} =
      Connections.user_connection(
        %{"id" => "aaa-bbb", "mail" => "user@example.com"},
        tenant_id: "tenant_1",
        scopes: ["openid", "email", "profile", "offline_access"]
      )

    assert {:error, %Error.ProviderError{reason: :invalid_response}} =
             OAuth.credential_lease(connection, %{"expires_in" => "120"})

    assert {:ok, lease} =
             OAuth.credential_lease(
               connection,
               %{"access_token" => "access", "expires_in" => "120"},
               issued_at: ~U[2026-01-01 00:00:00Z],
               scopes: ["openid"],
               metadata: %{source: :override}
             )

    assert lease.scopes == ["openid"]
    assert lease.expires_at == ~U[2026-01-01 00:02:00Z]
    assert lease.metadata.source == :override
  end

  test "authorize URL uses default scopes when scope is omitted" do
    url =
      OAuth.authorize_url(
        client_id: "client",
        redirect_uri: "https://demo.test/callback",
        state: "state"
      )

    params = URI.decode_query(URI.parse(url).query)
    assert params["scope"] == "openid email profile offline_access"
  end

  test "authorize URL omits nil optional parameters" do
    url =
      OAuth.authorize_url(
        client_id: "client",
        redirect_uri: "https://demo.test/callback",
        state: "state",
        code_challenge: nil,
        code_challenge_method: nil,
        login_hint: nil,
        prompt: nil,
        response_mode: nil
      )

    params = URI.decode_query(URI.parse(url).query)
    refute Map.has_key?(params, "code_challenge")
    refute Map.has_key?(params, "code_challenge_method")
    refute Map.has_key?(params, "login_hint")
    refute Map.has_key?(params, "prompt")
    refute Map.has_key?(params, "response_mode")
  end

  test "authorize URL raises when client_id is missing" do
    assert_raise Jido.Connect.Error.ConfigError,
                 ~r/client_id or MICROSOFT_CLIENT_ID is required/,
                 fn ->
                   OAuth.authorize_url(
                     redirect_uri: "https://demo.test/callback",
                     state: "state"
                   )
                 end
  end

  test "normalizes token responses without refresh_token" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        access_token: "access",
        token_type: "Bearer",
        expires_in: 3600,
        scope: "openid email"
      })
    end)

    assert {:ok, token} =
             OAuth.exchange_code("code",
               client_id: "client",
               client_secret: "secret",
               token_url: "https://oauth.test/token",
               redirect_uri: "https://demo.test/callback"
             )

    assert token.access_token == "access"
    refute Map.has_key?(token, :refresh_token)
  end

  test "normalizes token responses without expires_in" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        access_token: "access",
        token_type: "Bearer",
        scope: "openid"
      })
    end)

    _issued_at = ~U[2026-06-01 12:00:00Z]

    assert {:ok, token} =
             OAuth.exchange_code("code",
               client_id: "client",
               client_secret: "secret",
               token_url: "https://oauth.test/token",
               redirect_uri: "https://demo.test/callback"
             )

    # When expires_in is missing, normalize_token defaults to 3600s from now
    assert %DateTime{} = token.expires_at
  end

  test "credential lease falls back to connection scopes when token has no scope" do
    {:ok, connection} =
      Connections.user_connection(
        %{"id" => "aaa-bbb", "mail" => "user@example.com"},
        tenant_id: "tenant_1",
        scopes: ["openid", "email", "profile", "offline_access"]
      )

    assert {:ok, lease} =
             OAuth.credential_lease(
               connection,
               %{"access_token" => "access", "expires_in" => 3600},
               issued_at: ~U[2026-01-01 00:00:00Z]
             )

    assert lease.scopes == ["openid", "email", "profile", "offline_access"]
  end

  test "credential lease defaults expires_at when token has no expires_in" do
    {:ok, connection} =
      Connections.user_connection(
        %{"id" => "aaa-bbb", "mail" => "user@example.com"},
        tenant_id: "tenant_1",
        scopes: ["openid"]
      )

    issued_at = ~U[2026-06-01 12:00:00Z]

    assert {:ok, lease} =
             OAuth.credential_lease(
               connection,
               %{"access_token" => "access"},
               issued_at: issued_at
             )

    # Defaults to 3600s when expires_in is absent
    assert lease.expires_at == ~U[2026-06-01 13:00:00Z]
  end

  test "credential lease accepts caller expires_at override" do
    {:ok, connection} =
      Connections.user_connection(
        %{"id" => "aaa-bbb", "mail" => "user@example.com"},
        tenant_id: "tenant_1",
        scopes: ["openid"]
      )

    override_expires = ~U[2026-12-31 23:59:59Z]

    assert {:ok, lease} =
             OAuth.credential_lease(
               connection,
               %{"access_token" => "access", "expires_in" => 3600},
               expires_at: override_expires
             )

    assert lease.expires_at == override_expires
  end

  test "returns request-level errors for network failures" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.transport_error(conn, :econnrefused)
    end)

    assert {:error, %Error.ProviderError{reason: :request_error}} =
             OAuth.exchange_code("code",
               client_id: "client",
               client_secret: "secret",
               token_url: "https://oauth.test/token",
               redirect_uri: "https://demo.test/callback"
             )
  end

  test "handles non-JSON HTTP error bodies" do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(502)
      |> Plug.Conn.put_resp_header("content-type", "text/html")
      |> Plug.Conn.resp(502, "<html>Bad Gateway</html>")
    end)

    assert {:error, %Error.ProviderError{reason: :http_error, status: 502}} =
             OAuth.refresh_token("refresh",
               client_id: "client",
               client_secret: "secret",
               token_url: "https://oauth.test/token"
             )
  end
end
