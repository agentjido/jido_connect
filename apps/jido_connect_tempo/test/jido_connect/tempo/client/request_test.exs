defmodule Jido.Connect.Tempo.Client.RequestTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{Connection, Context, Error}
  alias Jido.Connect.Tempo.Client.Request

  describe "new/2" do
    test "builds an API token request for each allowed origin" do
      for origin <- ["https://api.tempo.io", "https://api.eu.tempo.io", "https://api.us.tempo.io"] do
        assert {:ok, request} =
                 Request.new(connection(metadata: %{api_origin: origin}), %{api_token: "tok-a"})

        assert %Request{
                 connection_id: "tempo_conn_1",
                 auth_profile: :api_token,
                 api_origin: ^origin,
                 account_id: "712020:acct-a"
               } = request

        assert Request.token(request) == "tok-a"
      end
    end

    test "builds an OAuth request from the access_token lease field" do
      assert {:ok, request} =
               Request.new(connection(profile: :oauth2_user), %{"access_token" => "oauth-a"})

      assert request.auth_profile == :oauth2_user
      assert Request.token(request) == "oauth-a"
    end

    test "redacts the token when inspected" do
      assert {:ok, request} = Request.new(connection(), %{api_token: "secret-token-value"})

      refute inspect(request) =~ "secret-token-value"
      assert inspect(request) =~ "https://api.us.tempo.io"
    end

    test "rejects a connection of another provider" do
      assert {:error, %Error.AuthError{reason: :tempo_connection_required}} =
               Request.new(connection(provider: :jira), %{api_token: "tok"})
    end

    test "rejects a missing or blank subject.account_id" do
      for subject <- [nil, %{}, %{account_id: ""}, %{account_id: "  "}, %{account_id: 42}] do
        assert {:error,
                %Error.AuthError{
                  reason: :tempo_account_id_required,
                  connection_id: "tempo_conn_1"
                }} =
                 Request.new(connection(subject: subject), %{api_token: "tok"})
      end
    end

    test "rejects a plaintext origin" do
      assert {:error, %Error.AuthError{reason: :insecure_tempo_api_origin}} =
               Request.new(connection(metadata: %{api_origin: "http://api.tempo.io"}), %{
                 api_token: "tok"
               })
    end

    test "rejects a missing or unlisted origin" do
      assert {:error, %Error.AuthError{reason: :tempo_api_origin_required}} =
               Request.new(connection(metadata: %{}), %{api_token: "tok"})

      for origin <- [
            "https://api.tempo.io/",
            "https://api.tempo.io/4",
            "https://API.tempo.io",
            "https://api.tempo.io:8443",
            "https://api.tempo.io.example.com",
            "https://example.atlassian.net",
            "api.tempo.io"
          ] do
        assert {:error,
                %Error.AuthError{
                  reason: :unsupported_tempo_api_origin,
                  details: %{allowed_origins: allowed}
                }} =
                 Request.new(connection(metadata: %{api_origin: origin}), %{api_token: "tok"})

        assert allowed == Request.origins()
      end
    end

    test "rejects a lease without the token field of the profile" do
      assert {:error,
              %Error.AuthError{
                reason: :tempo_credentials_required,
                details: %{profile: :api_token, missing_fields: [:api_token]}
              }} = Request.new(connection(), %{access_token: "oauth-token"})

      assert {:error,
              %Error.AuthError{
                reason: :tempo_credentials_required,
                details: %{profile: :oauth2_user, missing_fields: [:access_token]}
              } = error} =
               Request.new(connection(profile: :oauth2_user), %{api_token: "api-token-value"})

      refute inspect(error) =~ "api-token-value"

      assert {:error, %Error.AuthError{reason: :tempo_credentials_required}} =
               Request.new(connection(), %{api_token: ""})
    end

    test "rejects an unsupported auth profile" do
      assert {:error,
              %Error.AuthError{
                reason: :unsupported_tempo_auth_profile,
                details: %{allowed_profiles: [:api_token, :oauth2_user]}
              }} = Request.new(connection(profile: :pat), %{api_token: "tok"})
    end
  end

  # Tempo's links name https://api.tempo.io even on a regional origin.
  describe "tempo_link?/2" do
    test "accepts a link on any Tempo origin with the expected path" do
      for origin <- ["https://api.tempo.io", "https://api.eu.tempo.io", "https://api.us.tempo.io"] do
        assert Request.tempo_link?(origin <> "/4/accounts/26?expand=x", "/4/accounts/26")
      end

      assert Request.tempo_link?(
               "https://api.tempo.io/4/worklogs/user/712020%3Aa",
               "/4/worklogs/user/712020:a"
             )
    end

    test "rejects another origin, scheme, port or path and a relative link" do
      for link <- [
            "https://collector.example.com/4/accounts/26",
            "http://api.tempo.io/4/accounts/26",
            "https://api.tempo.io:8443/4/accounts/26",
            "https://api.tempo.io/4/accounts/27",
            "/4/accounts/26"
          ] do
        refute Request.tempo_link?(link, "/4/accounts/26")
      end
    end
  end

  describe "from_runtime/1" do
    test "builds a request from a handler runtime map" do
      context =
        Context.new!(%{
          tenant_id: "tenant_1",
          actor: %{id: "user_1", type: :app_user},
          connection: connection()
        })

      assert {:ok, %Request{account_id: "712020:acct-a"}} =
               Request.from_runtime(%{context: context, credentials: %{api_token: "tok"}})
    end

    test "rejects a runtime map without a connection" do
      assert {:error, %Error.AuthError{reason: :tempo_request_context_required}} =
               Request.from_runtime(%{credentials: %{api_token: "tok"}})
    end
  end

  defp connection(overrides \\ []) do
    Connection.new!(%{
      id: "tempo_conn_1",
      provider: Keyword.get(overrides, :provider, :tempo),
      profile: Keyword.get(overrides, :profile, :api_token),
      tenant_id: "tenant_1",
      owner_type: :app_user,
      owner_id: "user_1",
      subject: Keyword.get(overrides, :subject, %{account_id: "712020:acct-a"}),
      status: :connected,
      scopes: ["tempo.worklogs.read"],
      metadata: Keyword.get(overrides, :metadata, %{api_origin: "https://api.us.tempo.io"})
    })
  end
end
