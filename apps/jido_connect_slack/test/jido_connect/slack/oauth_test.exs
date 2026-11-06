defmodule Jido.Connect.Slack.OAuthTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.{Error, Sanitizer}
  alias Jido.Connect.Slack.{Client, OAuth}
  alias Jido.Connect.Slack.TestSupport.SyntheticFixture

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_slack, :slack_oauth_req_options,
      plug: {Req.Test, __MODULE__}
    )

    on_exit(fn ->
      Application.delete_env(:jido_connect_slack, :slack_oauth_req_options)
    end)
  end

  test "builds authorize URL" do
    url =
      OAuth.authorize_url(
        client_id: "client",
        redirect_uri: "https://demo.test/integrations/slack/oauth/callback",
        scopes: ["channels:read", "chat:write"],
        state: "state"
      )

    uri = URI.parse(url)
    params = URI.decode_query(uri.query)

    assert uri.scheme == "https"
    assert uri.host == "slack.com"
    assert uri.path == "/oauth/v2/authorize"
    assert params["client_id"] == "client"
    assert params["redirect_uri"] == "https://demo.test/integrations/slack/oauth/callback"
    assert params["scope"] == "channels:read,chat:write"
    assert params["state"] == "state"
    refute Map.has_key?(params, "user_scope")
  end

  test "sends user scopes as user_scope beside the bot scopes" do
    opts = [
      client_id: "client",
      redirect_uri: "https://demo.test/integrations/slack/oauth/callback",
      scopes: ["channels:read", "chat:write"],
      state: "state"
    ]

    without = OAuth.authorize_url(opts)

    url =
      OAuth.authorize_url(
        opts ++
          [user_scope: ["channels:history", "groups:history", "im:history", "mpim:history"]]
      )

    params = url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

    assert params == %{
             "client_id" => "client",
             "redirect_uri" => "https://demo.test/integrations/slack/oauth/callback",
             "scope" => "channels:read,chat:write",
             "state" => "state",
             "user_scope" => "channels:history,groups:history,im:history,mpim:history"
           }

    assert Map.delete(params, "user_scope") ==
             without |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

    assert OAuth.authorize_url(opts ++ [user_scope: []]) == without
    assert OAuth.authorize_url(opts ++ [user_scope: nil]) == without
  end

  # The oauth.v2.access responses are synthetic: written from Slack's
  # documentation, since recording one needs the app's client secret. Their
  # sources are named in test/fixtures/slack/synthetic.
  test "exchanges a code for the bot credential of a bot-only installation" do
    stub_oauth("oauth_v2_access_bot_only")

    assert {:ok, token} = exchange("code")

    assert_received {:oauth_request, "POST", ["Basic " <> _], form}
    assert form == %{"code" => "code", "redirect_uri" => "https://demo.test/callback"}

    assert token == %{
             access_token: "xoxb-synthetic-bot",
             token_type: "bot",
             scope: ["commands", "incoming-webhook"],
             bot_user_id: "U0KRQLJ9H",
             app_id: "A0KRD7HC3",
             team: %{"id" => "T9TK3CUKW"},
             enterprise: nil
           }
  end

  test "keeps the authorizing user's token from authed_user beside the bot credential" do
    stub_oauth("oauth_v2_access_bot_and_user")

    assert {:ok, token} = exchange("code")

    assert %{
             access_token: "xoxb-synthetic-bot",
             token_type: "bot",
             scope: ["commands", "incoming-webhook"],
             bot_user_id: "U0KRQLJ9H",
             app_id: "A0KRD7HC3",
             team: %{"id" => "T9TK3CUKW", "name" => "Slack Softball Team"},
             enterprise: %{"id" => "E12345678", "name" => "slack-sports"}
           } = token

    assert token.authed_user == %{
             id: "U1234",
             access_token: "xoxp-synthetic-user",
             token_type: "user",
             scope: ["chat:write"]
           }
  end

  test "a response without authed_user yields the bot credential only" do
    stub_oauth("oauth_v2_access_without_authed_user")

    assert {:ok, token} = exchange("code")

    assert token == %{
             access_token: "xoxb-synthetic-bot",
             token_type: "bot",
             scope: ["commands", "incoming-webhook"],
             bot_user_id: "U0KRQLJ9H",
             app_id: "A0KRD7HC3",
             team: %{"id" => "T9TK3CUKW", "name" => "Slack Softball Team"},
             enterprise: %{"id" => "E12345678", "name" => "slack-sports"}
           }
  end

  test "keeps the refresh token and expiry of a rotating user token" do
    stub_oauth("oauth_v2_access_token_rotation")
    before = DateTime.utc_now()

    assert {:ok, %{access_token: "xoxe.xoxb-synthetic-bot", authed_user: user}} =
             exchange("code")

    assert %{
             id: "U1234",
             access_token: "xoxe.xoxp-synthetic-user",
             token_type: "user",
             scope: ["chat:write"],
             refresh_token: "xoxe-synthetic-user-refresh",
             expires_in: 43_200,
             expires_at: %DateTime{} = expires_at
           } = user

    assert DateTime.diff(expires_at, before) in 43_200..43_202
  end

  test "a user-only response yields the user credential without a bot credential" do
    stub_oauth("oauth_v2_access_user_only")

    assert {:ok, token} = exchange("code")

    assert token == %{
             app_id: "A0118NQPZZC",
             team: %{"id" => "T024BE7LD"},
             enterprise: nil,
             authed_user: %{
               id: "U065VRX1T0",
               access_token: "xoxp-synthetic-user",
               token_type: "user",
               scope: ["identity.basic", "identity.email", "identity.avatar", "identity.team"]
             }
           }
  end

  test "normalizes Slack OAuth API and HTTP errors" do
    Req.Test.stub(__MODULE__, fn
      %{request_path: "/api-error"} = conn ->
        Req.Test.json(conn, SyntheticFixture.body!("oauth_v2_access_invalid_client_id"))

      conn ->
        conn
        |> Plug.Conn.put_status(503)
        |> Req.Test.json(%{error: "unavailable"})
    end)

    assert {:error,
            %Error.ProviderError{
              provider: :slack,
              reason: "invalid_client_id",
              status: 200
            }} =
             OAuth.exchange_code("bad",
               client_id: "client",
               client_secret: "secret",
               base_url: "https://slack.test/api-error"
             )

    assert {:error,
            %Error.ProviderError{
              provider: :slack,
              reason: :http_error,
              status: 503,
              details: %{body_summary: %{type: :map, keys: ["error"]}}
            }} =
             OAuth.exchange_code("bad",
               client_id: "client",
               client_secret: "secret",
               base_url: "https://slack.test/http-error"
             )
  end

  # Derived from the bot-only response: without its access token it holds
  # no token at all, since its authed_user has only an ID.
  test "normalizes successful token responses without any token" do
    body = SyntheticFixture.body!("oauth_v2_access_bot_only") |> Map.delete("access_token")
    Req.Test.stub(__MODULE__, &Req.Test.json(&1, body))

    assert {:error,
            %Error.ProviderError{
              provider: :slack,
              reason: :invalid_response,
              details: %{body_summary: %{type: :map, keys: keys}}
            }} = exchange("code")

    assert Enum.sort(keys) == body |> Map.keys() |> Enum.sort()
  end

  test "builds a redacted bot lease from a response that also holds a user token" do
    stub_oauth("oauth_v2_access_bot_and_user")
    assert {:ok, token} = exchange("code")

    assert {:ok, %Connect.CredentialLease{} = lease} =
             OAuth.bot_credential_lease(token, %{tenant_id: "tenant_1"})

    assert lease.connection_id == "slack-team-T9TK3CUKW"
    assert lease.provider == :slack
    assert lease.profile == :bot
    assert lease.tenant_id == "tenant_1"
    assert lease.owner_type == :tenant
    assert lease.owner_id == "T9TK3CUKW"
    assert lease.scopes == ["commands", "incoming-webhook"]
    assert lease.fields == %{access_token: "xoxb-synthetic-bot", slack_client: Client}
    assert lease.metadata.bot_user_id == "U0KRQLJ9H"

    for value <- [lease, Connect.CredentialLease.to_public_map(lease)],
        secret <- ["xoxb-synthetic-bot", "xoxp-synthetic-user"] do
      refute inspect(value) =~ secret
    end
  end

  test "builds a redacted user lease from the authorizing user's token" do
    stub_oauth("oauth_v2_access_bot_and_user")
    assert {:ok, token} = exchange("code")
    before = DateTime.utc_now()

    assert {:ok, %Connect.CredentialLease{} = lease} =
             OAuth.user_credential_lease(token, %{tenant_id: "tenant_1"})

    assert lease.connection_id == "slack-team-T9TK3CUKW-user-U1234"
    assert lease.provider == :slack
    assert lease.profile == :user
    assert lease.tenant_id == "tenant_1"
    assert lease.owner_type == :user
    assert lease.owner_id == "U1234"
    assert lease.scopes == ["chat:write"]
    assert lease.fields == %{access_token: "xoxp-synthetic-user", slack_client: Client}

    assert %{
             app_id: "A0KRD7HC3",
             user_id: "U1234",
             team: %{"id" => "T9TK3CUKW"},
             enterprise: %{"id" => "E12345678"},
             scopes: ["chat:write"]
           } = lease.metadata

    assert DateTime.diff(lease.expires_at, before) in 3599..3601

    for value <- [
          lease,
          Connect.CredentialLease.to_public_map(lease),
          Sanitizer.sanitize(token, :transport),
          Sanitizer.sanitize(token, :telemetry)
        ],
        secret <- ["xoxp-synthetic-user", "xoxb-synthetic-bot"] do
      refute inspect(value) =~ secret
    end
  end

  test "a user lease never outlives a rotating user token and leaves its refresh token out" do
    stub_oauth("oauth_v2_access_token_rotation")
    assert {:ok, token} = exchange("code")
    soon = DateTime.add(DateTime.utc_now(), 600, :second)
    expiring = put_in(token, [:authed_user, :expires_at], soon)

    assert {:ok, lease} = OAuth.user_credential_lease(expiring, %{tenant_id: "tenant_1"})
    assert lease.expires_at == soon
    assert lease.fields == %{access_token: "xoxe.xoxp-synthetic-user", slack_client: Client}

    later = DateTime.add(DateTime.utc_now(), 7200, :second)

    assert {:ok, %{expires_at: ^soon}} =
             OAuth.user_credential_lease(expiring, %{tenant_id: "tenant_1"}, expires_at: later)

    assert {:ok, lease} = OAuth.user_credential_lease(token, %{tenant_id: "tenant_1"})
    assert DateTime.compare(lease.expires_at, token.authed_user.expires_at) == :lt

    for secret <- ["xoxe.xoxp-synthetic-user", "xoxe-synthetic-user-refresh"] do
      refute inspect(lease) =~ secret
      refute inspect(Sanitizer.sanitize(token, :transport)) =~ secret
    end
  end

  test "leases a token the host read back from JSON, with string or atom keys" do
    stub_oauth("oauth_v2_access_token_rotation")
    assert {:ok, token} = exchange("code")
    soon = DateTime.add(DateTime.utc_now(), 600, :second)
    json = token |> put_in([:authed_user, :expires_at], soon) |> Jason.encode!()

    # An Ecto :map field gives string keys; keys: :atoms keeps the
    # expiry an ISO 8601 string as well.
    for stored <- [Jason.decode!(json), Jason.decode!(json, keys: :atoms)] do
      assert {:ok, user} = OAuth.user_credential_lease(stored, %{tenant_id: "tenant_1"})
      assert DateTime.compare(user.expires_at, soon) == :eq
      assert user.connection_id == "slack-team-T9TK3CUKW-user-U1234"
      assert user.owner_id == "U1234"
      assert user.scopes == ["chat:write"]
      assert user.fields.access_token == "xoxe.xoxp-synthetic-user"
      assert user.metadata.app_id == "A0KRD7HC3"

      assert {:ok, bot} = OAuth.bot_credential_lease(stored, %{tenant_id: "tenant_1"})
      assert bot.connection_id == "slack-team-T9TK3CUKW"
      assert bot.owner_id == "T9TK3CUKW"
      assert bot.scopes == ["commands", "incoming-webhook"]
      assert bot.fields.access_token == "xoxe.xoxb-synthetic-bot"
      assert bot.metadata.bot_user_id == "U0KRQLJ9H"
    end
  end

  test "an expires_at that is no DateTime or ISO 8601 string fails the user lease" do
    stub_oauth("oauth_v2_access_token_rotation")
    assert {:ok, token} = exchange("code")

    for expires_at <- ["tomorrow", "2026-11-03T12:00:00", 1_793_628_631] do
      assert {:error,
              %Error.AuthError{
                reason: :invalid_user_credential,
                details: %{field: :expires_at}
              } = error} =
               token
               |> put_in([:authed_user, :expires_at], expires_at)
               |> OAuth.user_credential_lease(%{tenant_id: "tenant_1"})

      refute inspect(error) =~ "synthetic"
    end
  end

  test "binds each lease to the host's connection of its profile" do
    stub_oauth("oauth_v2_access_bot_and_user")
    assert {:ok, token} = exchange("code")

    for {profile, lease_fun, access_token, scopes, token_user} <- [
          {:user, &OAuth.user_credential_lease/3, "xoxp-synthetic-user", ["chat:write"],
           %{user_id: "U1234"}},
          {:bot, &OAuth.bot_credential_lease/3, "xoxb-synthetic-bot",
           ["commands", "incoming-webhook"], %{bot_user_id: "U0KRQLJ9H"}}
        ] do
      # The connection's scopes differ from the token's; the lease keeps
      # the token's.
      connection = connection(profile, scopes: ["channels:history", "chat:write"])

      assert {:ok, lease} = lease_fun.(token, %{tenant_id: "tenant_1"}, connection: connection)
      assert lease.connection_id == connection.id
      assert Connect.CredentialLease.matches_connection?(lease, connection)
      assert lease.fields.access_token == access_token
      assert lease.scopes == scopes

      assert %{
               context: %{tenant_id: "tenant_1"},
               app_id: "A0KRD7HC3",
               team: %{"id" => "T9TK3CUKW"},
               enterprise: %{"id" => "E12345678"},
               scopes: ^scopes
             } = lease.metadata

      assert Map.take(lease.metadata, Map.keys(token_user)) == token_user
    end
  end

  test "a lease ends at an :expires_at before the default hour" do
    stub_oauth("oauth_v2_access_token_rotation")
    assert {:ok, token} = exchange("code")
    soon = DateTime.add(DateTime.utc_now(), 300, :second)

    # The user token expires in 12 hours, the bot token never.
    for lease_fun <- [&OAuth.bot_credential_lease/3, &OAuth.user_credential_lease/3] do
      assert {:ok, %{expires_at: ^soon}} =
               lease_fun.(token, %{tenant_id: "tenant_1"}, expires_at: soon)
    end
  end

  test "an :expires_at of nil leaves the lease at the default hour" do
    stub_oauth("oauth_v2_access_token_rotation")
    assert {:ok, token} = exchange("code")
    before = DateTime.utc_now()

    for lease_fun <- [&OAuth.bot_credential_lease/3, &OAuth.user_credential_lease/3] do
      assert {:ok, lease} = lease_fun.(token, %{tenant_id: "tenant_1"}, expires_at: nil)
      assert DateTime.diff(lease.expires_at, before) in 3599..3601
    end
  end

  test "a lease takes a given connection ID, else its connection's or its own" do
    stub_oauth("oauth_v2_access_bot_and_user")
    assert {:ok, token} = exchange("code")

    for {profile, default_id, lease_fun} <- [
          {:bot, "slack-team-T9TK3CUKW", &OAuth.bot_credential_lease/3},
          {:user, "slack-team-T9TK3CUKW-user-U1234", &OAuth.user_credential_lease/3}
        ] do
      connection = connection(profile)

      for {opts, connection_id} <- [
            {[], default_id},
            {[connection_id: nil], default_id},
            {[connection_id: "host-lease"], "host-lease"},
            {[connection: connection], connection.id},
            {[connection: connection, connection_id: nil], connection.id},
            {[connection: connection, connection_id: "host-lease"], "host-lease"}
          ] do
        assert {:ok, %{connection_id: ^connection_id}} =
                 lease_fun.(token, %{tenant_id: "tenant_1"}, opts),
               "#{profile} #{inspect(Keyword.delete(opts, :connection))}"
      end
    end
  end

  test "refuses a connection or profile other than the token's" do
    stub_oauth("oauth_v2_access_bot_and_user")
    assert {:ok, token} = exchange("code")
    context = %{tenant_id: "tenant_1"}

    for {profile, other, lease_fun} <- [
          {:user, :bot, &OAuth.user_credential_lease/3},
          {:bot, :user, &OAuth.bot_credential_lease/3}
        ] do
      connection_id = "slack-#{other}-connection"

      assert {:error,
              %Error.AuthError{
                reason: :unsupported_auth_profile,
                connection_id: ^connection_id,
                details: %{profile: ^other, allowed_profiles: [^profile]}
              } = error} = lease_fun.(token, context, connection: connection(other))

      refute inspect(error) =~ "synthetic"

      assert {:error,
              %Error.AuthError{
                reason: :unsupported_auth_profile,
                connection_id: "host-lease",
                details: %{profile: ^other, allowed_profiles: [^profile]}
              }} = lease_fun.(token, context, profile: other, connection_id: "host-lease")

      assert {:error,
              %Error.AuthError{
                reason: :credential_connection_mismatch,
                connection_id: "github-connection",
                details: %{
                  field: :provider,
                  expected: :github,
                  actual: :slack,
                  lease_connection_id: "github-connection"
                }
              }} =
               lease_fun.(token, context,
                 connection: connection(profile, id: "github-connection", provider: :github)
               )

      assert {:ok, %{profile: ^profile}} = lease_fun.(token, context, profile: profile)

      assert {:ok, %{profile: ^profile}} =
               lease_fun.(token, context, connection: connection(profile))

      # With a connection, its profile decides and :profile is ignored.
      assert {:ok, %{profile: ^profile}} =
               lease_fun.(token, context, connection: connection(profile), profile: other)
    end
  end

  test "a lease needs the credential of its profile in the token response" do
    stub_oauth("oauth_v2_access_bot_only")
    assert {:ok, bot_only} = exchange("code")

    assert {:error, %Error.AuthError{reason: :missing_user_credential} = error} =
             OAuth.user_credential_lease(bot_only, %{tenant_id: "tenant_1"})

    refute inspect(error) =~ "xoxb-synthetic-bot"

    stub_oauth("oauth_v2_access_user_only")
    assert {:ok, user_only} = exchange("code")

    assert {:error, %Error.AuthError{reason: :missing_bot_credential} = error} =
             OAuth.bot_credential_lease(user_only, %{tenant_id: "tenant_1"})

    refute inspect(error) =~ "xoxp-synthetic-user"

    assert {:ok, %{profile: :user, owner_id: "U065VRX1T0"}} =
             OAuth.user_credential_lease(user_only, %{tenant_id: "tenant_1"})
  end

  # A host connection for the token of the oauth_v2_access_bot_and_user
  # response.
  defp connection(profile, overrides \\ []) do
    {owner_type, owner_id} =
      case profile do
        :user -> {:user, "U1234"}
        :bot -> {:tenant, "T9TK3CUKW"}
      end

    %{
      id: "slack-#{profile}-connection",
      provider: :slack,
      profile: profile,
      tenant_id: "tenant_1",
      owner_type: owner_type,
      owner_id: owner_id,
      status: :connected,
      scopes: ["chat:write"]
    }
    |> Map.merge(Map.new(overrides))
    |> Connect.Connection.new!()
  end

  defp stub_oauth(name) do
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      authorization = Plug.Conn.get_req_header(conn, "authorization")
      send(test_pid, {:oauth_request, conn.method, authorization, URI.decode_query(body)})
      Req.Test.json(conn, SyntheticFixture.body!(name))
    end)
  end

  defp exchange(code) do
    OAuth.exchange_code(code,
      client_id: "client",
      client_secret: "secret",
      redirect_uri: "https://demo.test/callback",
      base_url: "https://slack.test"
    )
  end
end
