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
end
