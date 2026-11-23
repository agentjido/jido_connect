defmodule Jido.Connect.GitHub.OAuthTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.GitHub.OAuth

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_github, :github_oauth_req_options,
      plug: {Req.Test, __MODULE__}
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_github, :github_oauth_req_options)
    end)
  end

  test "builds authorize URL" do
    url =
      OAuth.authorize_url(
        client_id: "client",
        redirect_uri: "https://demo.test/integrations/github/oauth/callback",
        scope: ["repo", "read:user"],
        code_challenge: "proof-key-challenge",
        state: "state"
      )

    uri = URI.parse(url)
    params = URI.decode_query(uri.query)

    assert uri.scheme == "https"
    assert uri.host == "github.com"
    assert uri.path == "/login/oauth/authorize"
    assert params["client_id"] == "client"
    assert params["redirect_uri"] == "https://demo.test/integrations/github/oauth/callback"
    assert params["scope"] == "repo read:user"
    assert params["state"] == "state"
    assert params["code_challenge"] == "proof-key-challenge"
    assert params["code_challenge_method"] == "S256"
  end

  test "exchanges code for token" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert %{"code_verifier" => "proof-key-verifier"} = JSON.decode!(body)

      Req.Test.json(conn, %{
        access_token: "token",
        token_type: "bearer",
        scope: "repo,read:user"
      })
    end)

    assert {:ok, token} =
             OAuth.exchange_code("code",
               client_id: "client",
               client_secret: "secret",
               code_verifier: "proof-key-verifier",
               base_url: "https://github.test"
             )

    assert token.access_token == "token"
    assert token.scope == ["repo", "read:user"]
  end

  test "starts headless authorization and reports polling responses" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.request_path == "/login/device/code"
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert URI.decode_query(body) == %{"client_id" => "client", "scope" => "repo"}

      Req.Test.json(conn, %{
        device_code: "secret-device-code",
        user_code: "USER-CODE",
        verification_uri: "https://github.com/login/device",
        expires_in: 900,
        interval: 5
      })
    end)

    for result <- [
          %{error: "authorization_pending"},
          %{error: "slow_down"},
          %{access_token: "token", scope: "repo"}
        ] do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.request_path == "/login/oauth/access_token"
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert URI.decode_query(body) == %{
                 "client_id" => "client",
                 "device_code" => "secret-device-code",
                 "grant_type" => "urn:ietf:params:oauth:grant-type:device_code"
               }

        Req.Test.json(conn, result)
      end)
    end

    opts = [client_id: "client", scope: ["repo"]]

    assert {:ok, %{device_code: code, user_code: "USER-CODE", expires_in: 900, interval: 5}} =
             OAuth.start_device_authorization(opts)

    assert {:pending, :authorization_pending} = OAuth.poll_device_authorization(code, opts)
    assert {:pending, :slow_down} = OAuth.poll_device_authorization(code, opts)

    assert {:ok, %{access_token: "token", scope: ["repo"]}} =
             OAuth.poll_device_authorization(code, opts)
  end

  test "refresh returns both tokens with expirations and keeps failures free of token values" do
    Req.Test.expect(__MODULE__, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert URI.decode_query(body) == %{
               "client_id" => "client",
               "client_secret" => "secret",
               "grant_type" => "refresh_token",
               "refresh_token" => "previous-refresh-token"
             }

      Req.Test.json(conn, %{
        access_token: "new-token",
        refresh_token: "new-refresh-token",
        expires_in: 60,
        refresh_token_expires_in: 600,
        scope: "repo"
      })
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        error: "bad_refresh_token",
        error_description: "previous-refresh-token"
      })
    end)

    opts = [client_id: "client", client_secret: "secret"]

    assert {:ok,
            %{
              access_token: "new-token",
              refresh_token: "new-refresh-token",
              expires_in: 60,
              refresh_token_expires_in: 600,
              scope: ["repo"]
            }} = OAuth.refresh_token("previous-refresh-token", opts)

    assert {:error, %Error.ProviderError{reason: "bad_refresh_token"} = error} =
             OAuth.refresh_token("previous-refresh-token", opts)

    refute inspect(error) =~ "previous-refresh-token"
  end

  test "returns OAuth error response" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{
        error: "bad_verification_code",
        error_description: "The code passed is incorrect or expired."
      })
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :github,
              reason: "bad_verification_code",
              details: %{description: "The code passed is incorrect or expired."}
            }} =
             OAuth.exchange_code("bad",
               client_id: "client",
               client_secret: "secret",
               base_url: "https://github.test"
             )
  end

  test "normalizes malformed successful token responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      Req.Test.json(conn, %{token_type: "bearer"})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :github,
              reason: :invalid_response,
              details: %{body_summary: %{type: :map, keys: ["token_type"]}}
            }} =
             OAuth.exchange_code("code",
               client_id: "client",
               client_secret: "secret",
               base_url: "https://github.test"
             )
  end

  test "normalizes HTTP errors and revokes tokens" do
    Req.Test.stub(__MODULE__, fn
      %{method: "POST"} = conn ->
        conn
        |> Plug.Conn.put_status(502)
        |> Req.Test.json(%{message: "upstream unavailable"})

      %{method: "DELETE", request_path: "/applications/client/token"} = conn ->
        assert ["Basic " <> _] = Plug.Conn.get_req_header(conn, "authorization")
        Plug.Conn.resp(conn, 204, "")
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :github,
              reason: :http_error,
              status: 502,
              details: %{message: "upstream unavailable"}
            }} =
             OAuth.exchange_code("bad",
               client_id: "client",
               client_secret: "secret",
               base_url: "https://github.test"
             )

    assert :ok =
             OAuth.revoke_token("token",
               client_id: "client",
               client_secret: "secret",
               api_base_url: "https://github.test"
             )
  end

  test "normalizes token revocation HTTP errors" do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(403)
      |> Req.Test.json(%{message: "Forbidden"})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :github,
              reason: :http_error,
              status: 403,
              details: %{message: "Forbidden"}
            }} =
             OAuth.revoke_token("token",
               client_id: "client",
               client_secret: "secret",
               api_base_url: "https://github.test"
             )
  end
end
