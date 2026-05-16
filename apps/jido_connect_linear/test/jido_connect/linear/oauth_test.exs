defmodule Jido.Connect.Linear.OAuthTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.Linear.OAuth

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_linear, :linear_oauth_req_options,
      plug: {Req.Test, __MODULE__}
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_linear, :linear_oauth_req_options)
    end)
  end

  test "builds authorize URL with Linear parameters" do
    url =
      OAuth.authorize_url(
        client_id: "client",
        redirect_uri: "https://demo.test/integrations/linear/oauth/callback",
        scope: ["read", "write"],
        state: "state"
      )

    uri = URI.parse(url)
    params = URI.decode_query(uri.query)

    assert uri.scheme == "https"
    assert uri.host == "linear.app"
    assert uri.path == "/oauth/authorize"
    assert params["client_id"] == "client"
    assert params["redirect_uri"] == "https://demo.test/integrations/linear/oauth/callback"
    assert params["scope"] == "read write"
    assert params["state"] == "state"
    assert params["response_type"] == "code"
    assert params["prompt"] == "consent"
  end

  test "exchanges code for token" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"

      Req.Test.json(conn, %{
        access_token: "at-token",
        refresh_token: "rt-token",
        token_type: "bearer",
        scope: "read write",
        expires_in: 3600
      })
    end)

    assert {:ok, token} =
             OAuth.exchange_code("code",
               client_id: "client",
               client_secret: "secret",
               redirect_uri: "https://demo.test/callback",
               token_url: "https://auth.test"
             )

    assert token.access_token == "at-token"
    assert token.refresh_token == "rt-token"
    assert token.scope == ["read", "write"]
    assert token.expires_in == 3600
  end

  test "returns OAuth error response" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        error: "invalid_grant",
        error_description: "The authorization code is invalid."
      })
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :linear,
              reason: "invalid_grant",
              details: %{description: "The authorization code is invalid."}
            }} =
             OAuth.exchange_code("bad",
               client_id: "client",
               client_secret: "secret",
               redirect_uri: "https://demo.test/callback",
               token_url: "https://auth.test"
             )
  end

  test "normalizes malformed successful token responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{token_type: "bearer"})
    end)

    assert {:error, %Error.ProviderError{provider: :linear, reason: :invalid_response}} =
             OAuth.exchange_code("code",
               client_id: "client",
               client_secret: "secret",
               redirect_uri: "https://demo.test/callback",
               token_url: "https://auth.test"
             )
  end

  test "refreshes an access token" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        access_token: "new-at-token",
        refresh_token: "new-rt-token",
        token_type: "bearer",
        scope: "read",
        expires_in: 3600
      })
    end)

    assert {:ok, token} =
             OAuth.refresh_token("old-rt",
               client_id: "client",
               client_secret: "secret",
               token_url: "https://auth.test"
             )

    assert token.access_token == "new-at-token"
    assert token.refresh_token == "new-rt-token"
  end

  test "normalizes HTTP errors" do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(502)
      |> Req.Test.json(%{message: "upstream unavailable"})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :linear,
              reason: :http_error,
              status: 502,
              details: %{message: "upstream unavailable"}
            }} =
             OAuth.exchange_code("code",
               client_id: "client",
               client_secret: "secret",
               redirect_uri: "https://demo.test/callback",
               token_url: "https://auth.test"
             )
  end
end
