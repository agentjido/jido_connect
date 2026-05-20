defmodule Jido.Connect.GitLab.OAuthTest do
  @moduledoc """
  Offline tests for GitLab OAuth2 token exchange.

  Req.Test uses Plug.Conn internally, so Plug must be available at test
  runtime. The package declares {:plug, "~> 1.19", only: :test} in mix.exs.
  """
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.GitLab.OAuth

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_gitlab, :gitlab_oauth_req_options,
      plug: {Req.Test, __MODULE__}
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_gitlab, :gitlab_oauth_req_options)
    end)
  end

  describe "authorize_url/1" do
    test "builds authorize URL with GitLab parameters" do
      url =
        OAuth.authorize_url(
          client_id: "client",
          redirect_uri: "https://demo.test/integrations/gitlab/oauth/callback",
          scope: ["api", "read_repository"],
          state: "state"
        )

      uri = URI.parse(url)
      params = URI.decode_query(uri.query)

      assert uri.scheme == "https"
      assert uri.host == "gitlab.com"
      assert uri.path == "/oauth/authorize"
      assert params["client_id"] == "client"
      assert params["redirect_uri"] == "https://demo.test/integrations/gitlab/oauth/callback"
      assert params["scope"] == "api read_repository"
      assert params["state"] == "state"
      assert params["response_type"] == "code"
    end

    test "supports self-hosted GitLab instances" do
      url =
        OAuth.authorize_url(
          client_id: "client",
          redirect_uri: "https://demo.test/callback",
          state: "state",
          authorize_url: "https://gitlab.example.com/oauth/authorize"
        )

      uri = URI.parse(url)
      assert uri.host == "gitlab.example.com"
      assert uri.path == "/oauth/authorize"
    end
  end

  describe "exchange_code/2" do
    test "exchanges code for token with correct request body" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "POST"

        body = conn |> Req.Test.raw_body() |> Jason.decode!()
        assert body["grant_type"] == "authorization_code"
        assert body["client_id"] == "client"
        assert body["client_secret"] == "secret"
        assert body["code"] == "code"
        assert body["redirect_uri"] == "https://demo.test/callback"

        Req.Test.json(conn, %{
          access_token: "at-token",
          refresh_token: "rt-token",
          token_type: "bearer",
          scope: "api read_repository",
          created_at: 1_700_000_000
        })
      end)

      assert {:ok, token} =
               OAuth.exchange_code("code",
                 client_id: "client",
                 client_secret: "secret",
                 redirect_uri: "https://demo.test/callback",
                 token_url: "https://gitlab.test"
               )

      assert token.access_token == "at-token"
      assert token.refresh_token == "rt-token"
      assert token.scope == ["api", "read_repository"]
      assert token.created_at == 1_700_000_000
    end

    test "returns OAuth error response" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{
          error: "invalid_grant",
          error_description: "The authorization code is invalid."
        })
      end)

      assert {:error, %Error.ProviderError{provider: :gitlab, reason: "invalid_grant"} = error} =
               OAuth.exchange_code("bad",
                 client_id: "client",
                 client_secret: "secret",
                 redirect_uri: "https://demo.test/callback",
                 token_url: "https://gitlab.test"
               )

      assert error.details[:description] == "The authorization code is invalid."
      assert error.details[:body_summary]
    end

    test "normalizes malformed successful token responses" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.json(conn, %{token_type: "bearer"})
      end)

      assert {:error, %Error.ProviderError{provider: :gitlab, reason: :invalid_response} = error} =
               OAuth.exchange_code("code",
                 client_id: "client",
                 client_secret: "secret",
                 redirect_uri: "https://demo.test/callback",
                 token_url: "https://gitlab.test"
               )

      assert error.details[:body_summary]
      refute error.details[:body]
    end

    test "normalizes HTTP errors" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(502)
        |> Req.Test.json(%{message: "upstream unavailable"})
      end)

      assert {:error,
              %Error.ProviderError{
                provider: :gitlab,
                reason: :http_error,
                status: 502
              } = error} =
               OAuth.exchange_code("code",
                 client_id: "client",
                 client_secret: "secret",
                 redirect_uri: "https://demo.test/callback",
                 token_url: "https://gitlab.test"
               )

      assert error.details[:message] == "upstream unavailable"
    end

    test "normalizes transport errors" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, %Error.ProviderError{provider: :gitlab, reason: :request_error} = error} =
               OAuth.exchange_code("code",
                 client_id: "client",
                 client_secret: "secret",
                 redirect_uri: "https://demo.test/callback",
                 token_url: "https://gitlab.test"
               )

      assert is_map(error.details[:reason])
    end
  end

  describe "refresh_token/2" do
    test "refreshes an access token with correct request body" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "POST"

        body = conn |> Req.Test.raw_body() |> Jason.decode!()
        assert body["grant_type"] == "refresh_token"
        assert body["client_id"] == "client"
        assert body["client_secret"] == "secret"
        assert body["refresh_token"] == "old-rt"

        Req.Test.json(conn, %{
          access_token: "new-at-token",
          refresh_token: "new-rt-token",
          token_type: "bearer",
          scope: "read_api",
          created_at: 1_700_000_100
        })
      end)

      assert {:ok, token} =
               OAuth.refresh_token("old-rt",
                 client_id: "client",
                 client_secret: "secret",
                 token_url: "https://gitlab.test"
               )

      assert token.access_token == "new-at-token"
      assert token.refresh_token == "new-rt-token"
    end
  end

  describe "revoke_token/2" do
    test "revokes a token successfully" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.method == "POST"

        body = conn |> Req.Test.raw_body() |> Jason.decode!()
        assert body["client_id"] == "client"
        assert body["client_secret"] == "secret"
        assert body["token"] == "at-token"

        Plug.Conn.resp(conn, 200, "")
      end)

      assert :ok =
               OAuth.revoke_token("at-token",
                 client_id: "client",
                 client_secret: "secret",
                 token_url: "https://gitlab.test/oauth/token"
               )
    end

    test "normalizes revocation HTTP errors" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(403)
        |> Req.Test.json(%{message: "Forbidden"})
      end)

      assert {:error,
              %Error.ProviderError{
                provider: :gitlab,
                reason: :http_error,
                status: 403
              }} =
               OAuth.revoke_token("at-token",
                 client_id: "client",
                 client_secret: "secret",
                 token_url: "https://gitlab.test/oauth/token"
               )
    end
  end
end
