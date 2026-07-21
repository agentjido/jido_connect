defmodule Jido.Connect.Nextcloud.OAuthTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Nextcloud.OAuth

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_nextcloud, :nextcloud_oauth_req_options,
      plug: {Req.Test, __MODULE__}
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_nextcloud, :nextcloud_oauth_req_options)
    end)
  end

  test "builds authorize URL" do
    url =
      OAuth.authorize_url(
        base_url: "https://cloud.example.com/",
        client_id: "client",
        redirect_uri: "https://app.example.com/callback",
        state: "state"
      )

    uri = URI.parse(url)
    params = URI.decode_query(uri.query)

    assert uri.host == "cloud.example.com"
    assert uri.path == "/apps/oauth2/authorize"
    assert params["client_id"] == "client"
    assert params["response_type"] == "code"
  end

  test "exchanges code for token" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/apps/oauth2/api/v1/token"
      body = URI.decode_query(Req.Test.raw_body(conn))
      assert body["grant_type"] == "authorization_code"

      Req.Test.json(conn, %{
        access_token: "access",
        refresh_token: "refresh",
        token_type: "Bearer"
      })
    end)

    assert {:ok, token} =
             OAuth.exchange_code("code",
               base_url: "https://cloud.example.com",
               client_id: "client",
               client_secret: "secret",
               redirect_uri: "https://app.example.com/callback"
             )

    assert token.base_url == "https://cloud.example.com"
    assert token.access_token == "access"
    assert token.refresh_token == "refresh"
  end

  test "refreshes token" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/apps/oauth2/api/v1/token"
      body = URI.decode_query(Req.Test.raw_body(conn))
      assert body["grant_type"] == "refresh_token"
      assert body["refresh_token"] == "refresh"

      Req.Test.json(conn, %{
        access_token: "new-access",
        refresh_token: "new-refresh",
        token_type: "Bearer",
        expires_in: 3600
      })
    end)

    assert {:ok, token} =
             OAuth.refresh_token("refresh",
               base_url: "https://cloud.example.com/",
               client_id: "client",
               client_secret: "secret"
             )

    assert token.base_url == "https://cloud.example.com"
    assert token.access_token == "new-access"
    assert token.expires_in == 3600
  end

  test "returns provider error from oauth error body" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{error: "invalid_grant", error_description: "Bad code"})
    end)

    assert {:error, error} =
             OAuth.exchange_code("bad",
               base_url: "https://cloud.example.com",
               client_id: "client",
               client_secret: "secret",
               redirect_uri: "https://app.example.com/callback"
             )

    assert error.reason == "invalid_grant"
  end
end
