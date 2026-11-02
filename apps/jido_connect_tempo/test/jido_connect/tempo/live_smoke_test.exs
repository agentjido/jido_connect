defmodule Jido.Connect.Tempo.LiveSmokeTest do
  @moduledoc """
  Live smoke checks against the Tempo test account of the Atlassian test site.

      MIX_ENV=test mix do --app jido_connect_tempo test --only live_smoke

  See `docs/live_smoke_tests.md` for the variables and the recording mode.
  The Atlassian account ID of the test user comes from Jira
  `GET /rest/api/3/myself`; that helper call is not recorded.

  ExUnit prints the arguments of a failing call, so checks that involve a real
  token compute a boolean first and fail with a fixed message.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect.{Connection, Error}
  alias Jido.Connect.Tempo.Client.{Pagination, Request, Transport}
  alias Jido.Connect.Tempo.{OAuth, ScopeResolver}

  @recorder {:jido_connect_tempo, :tempo_req_options}
  @oauth_recorder {:jido_connect_tempo, :tempo_oauth_req_options}
  @oauth ["TEMPO_OAUTH_CLIENT_ID", "TEMPO_OAUTH_CLIENT_SECRET", "TEMPO_OAUTH_REDIRECT_URI"]
  @october [params: [from: "2026-10-01", to: "2026-10-31"]]
  @jira ["JIRA_SITE", "JIRA_EMAIL", "JIRA_API_TOKEN"]
  # This file lies in apps/jido_connect_tempo/test/jido_connect/tempo.
  @repository Path.expand("../../../../..", __DIR__)

  @tag env!(["TEMPO_API_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "reads periods with the API token", %{env: env} do
    request = request!(env, :api_token, env["TEMPO_API_TOKEN"])
    LiveSmoke.record(@recorder, :tempo, "periods")

    assert {:ok, %{"periods" => [_ | _]}} = Transport.get(request, "/4/periods", @october)
  end

  @tag env!(["TEMPO_OAUTH_ACCESS_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "reads periods with the OAuth access token", %{env: env} do
    request = request!(env, :oauth2_user, env["TEMPO_OAUTH_ACCESS_TOKEN"])
    LiveSmoke.record(@recorder, :tempo, "periods_oauth")

    assert {:ok, %{"periods" => [_ | _]}} = Transport.get(request, "/4/periods", @october)
  end

  @tag env!(["TEMPO_API_ORIGIN" | @jira])
  test "an invalid token gets a normalized auth error without the token", %{env: env} do
    token = "jido-connect-invalid-tempo-token"
    request = request!(env, :api_token, token)
    LiveSmoke.record(@recorder, :tempo, "unauthorized")

    assert {:error,
            %Error.ProviderError{provider: :tempo, reason: :unauthorized, status: 401} = error} =
             Transport.get(request, "/4/periods", @october)

    refute_leak(error, token)
  end

  @tag env!(["TEMPO_API_TOKEN" | @jira])
  test "a token sent to another cluster gets an auth error", %{env: env} do
    token = env["TEMPO_API_TOKEN"]
    request = request!(env, :api_token, token, "https://api.eu.tempo.io")
    LiveSmoke.record(@recorder, :tempo, "wrong_cluster")

    assert {:error, %Error.ProviderError{reason: :unauthorized, status: 401} = error} =
             Transport.get(request, "/4/periods", @october)

    refute_leak(error, token)
  end

  @tag env!(["TEMPO_API_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "an unknown worklog gets a not-found error", %{env: env} do
    request = request!(env, :api_token, env["TEMPO_API_TOKEN"])
    LiveSmoke.record(@recorder, :tempo, "not_found")

    assert {:error, %Error.ProviderError{reason: :not_found, status: 404, details: details}} =
             Transport.get(request, "/4/worklogs/999999999")

    assert details.message == "Worklog cannot be found"
  end

  @tag env!(["TEMPO_API_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "an unknown route gets a not-found error with a non-JSON body", %{env: env} do
    request = request!(env, :api_token, env["TEMPO_API_TOKEN"])
    LiveSmoke.record(@recorder, :tempo, "not_found_html")

    assert {:error, %Error.ProviderError{reason: :not_found, status: 404}} =
             Transport.get(request, "/4/global-configurations")
  end

  @tag env!(["TEMPO_API_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "an invalid date gets a bad-request error", %{env: env} do
    request = request!(env, :api_token, env["TEMPO_API_TOKEN"])
    LiveSmoke.record(@recorder, :tempo, "bad_request")

    assert {:error, %Error.ProviderError{reason: :bad_request, status: 400, details: details}} =
             Transport.get(request, "/4/periods", params: [from: "not-a-date", to: "2026-10-31"])

    assert details.message =~ "not-a-date"
  end

  @tag env!(["TEMPO_API_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "a read the test user may not do gets a forbidden error", %{env: env} do
    request = request!(env, :api_token, env["TEMPO_API_TOKEN"])
    LiveSmoke.record(@recorder, :tempo, "forbidden")

    assert {:error, %Error.ProviderError{reason: :forbidden, status: 403}} =
             Transport.get(request, "/4/holiday-schemes")
  end

  @tag env!(["TEMPO_API_TOKEN", "TEMPO_API_ORIGIN" | @jira])
  test "pages through the October worklogs of the test user", %{env: env} do
    request = request!(env, :api_token, env["TEMPO_API_TOKEN"])
    path = "/4/worklogs/user/" <> URI.encode(request.account_id, &URI.char_unreserved?/1)
    LiveSmoke.record(@recorder, :tempo, "worklogs_page")

    assert {:ok, worklogs} = Pagination.collect(request, path, @october)

    count = length(worklogs)
    assert count > 50, "expected more than one page of 50 worklogs, got #{count}"
    own? = Enum.all?(worklogs, &(get_in(&1, ["author", "accountId"]) == request.account_id))
    assert own?, "every worklog belongs to the test user"
  end

  # The token endpoint's rejections are recorded with an invented code and an
  # invented refresh token. A successful exchange needs the code of one
  # browser authorization and every refresh replaces both tokens, so that
  # test runs only with TEMPO_OAUTH_CODE and never uses the stored refresh
  # token.
  @tag env!(@oauth)
  test "the token endpoint rejects an invented authorization code", %{env: env} do
    LiveSmoke.record(@oauth_recorder, :tempo, "oauth_invalid_code")

    assert {:error,
            %Error.ProviderError{provider: :tempo, reason: :forbidden, status: 403} = error} =
             OAuth.exchange_code("jido-connect-invented-code", oauth_opts(env))

    refute_leak(error, env["TEMPO_OAUTH_CLIENT_SECRET"])
  end

  @tag env!(@oauth)
  test "the token endpoint rejects an invented refresh token", %{env: env} do
    LiveSmoke.record(@oauth_recorder, :tempo, "oauth_invalid_refresh_token")

    assert {:error,
            %Error.ProviderError{provider: :tempo, reason: :forbidden, status: 403} = error} =
             OAuth.refresh("jido-connect-invented-refresh-token", oauth_opts(env))

    refute_leak(error, env["TEMPO_OAUTH_CLIENT_SECRET"])
  end

  # Consumes the code and rotates the new pair once. Each pair is written to
  # TEMPO_OAUTH_TOKEN_FILE before anything else can fail: the code is spent
  # after the exchange, and the exchanged pair is invalid after the refresh.
  @tag env!(["TEMPO_OAUTH_CODE", "TEMPO_OAUTH_TOKEN_FILE", "TEMPO_API_ORIGIN"] ++ @oauth ++ @jira)
  test "exchanges a code and refreshes the new pair once", %{env: env} do
    code = env["TEMPO_OAUTH_CODE"]
    file = env["TEMPO_OAUTH_TOKEN_FILE"]
    prepare_token_file!(file)

    LiveSmoke.record(@oauth_recorder, :tempo, "oauth_exchange")
    issued_at = DateTime.utc_now()
    exchanged = token!(OAuth.exchange_code(code, oauth_opts(env)), "code exchange")
    write_token_file!(file, exchanged, issued_at)
    refute_recorded_secrets!("oauth_exchange", [code | token_values(exchanged)])

    LiveSmoke.record(@oauth_recorder, :tempo, "oauth_refresh")
    issued_at = DateTime.utc_now()
    refreshed = token!(OAuth.refresh(refresh_token(exchanged), oauth_opts(env)), "refresh")
    write_token_file!(file, refreshed, issued_at)

    refute_recorded_secrets!(
      "oauth_refresh",
      [code | token_values(exchanged) ++ token_values(refreshed)]
    )

    assert usable_token?(exchanged), "the exchanged token lacks expiry, scope or worklog read"
    assert usable_token?(refreshed), "the refreshed token lacks expiry, scope or worklog read"
    assert rotated?(exchanged, refreshed), "the refresh returned a token of the exchanged pair"

    read =
      env
      |> request!(:oauth2_user, access_token(refreshed))
      |> Transport.get("/4/periods", @october)

    assert match?({:ok, %{"periods" => [_ | _]}}, read),
           "the refreshed access token did not read /4/periods"

    stale =
      env
      |> request!(:oauth2_user, access_token(exchanged))
      |> Transport.get("/4/periods", @october)

    assert match?({:error, %Error.ProviderError{reason: :unauthorized, status: 401}}, stale),
           "the exchanged access token did not get a 401 after the refresh"
  end

  # The helpers below take token maps. Each has a clause for any argument, so
  # no FunctionClauseError prints a token.

  defp token!({:ok, %{access_token: _, refresh_token: _} = token}, _step), do: token

  defp token!({:error, %Error.ProviderError{} = error}, step),
    do: flunk("the #{step} failed: #{inspect(error.reason)}, status #{inspect(error.status)}")

  defp token!(_result, step), do: flunk("the #{step} returned an unexpected result")

  defp access_token(%{access_token: token}), do: token
  defp access_token(_token), do: flunk("no access token")

  defp refresh_token(%{refresh_token: token}), do: token
  defp refresh_token(_token), do: flunk("no refresh token")

  defp token_values(%{access_token: access, refresh_token: refresh}), do: [access, refresh]
  defp token_values(_token), do: flunk("no token pair")

  defp usable_token?(%{expires_in: expires_in, scope: [_ | _] = scope})
       when is_integer(expires_in) and expires_in > 0,
       do: "tempo.worklogs.read" in ScopeResolver.granted_labels(scope)

  defp usable_token?(_token), do: false

  defp rotated?(%{access_token: a1, refresh_token: r1}, %{access_token: a2, refresh_token: r2}),
    do: a1 != a2 and r1 != r2

  defp rotated?(_exchanged, _refreshed), do: false

  # The file must be an absolute path outside the repository, so no commit can
  # pick up the pair; Mix runs the test in the app directory, where a relative
  # path would land. It must be new or empty, so a run cannot overwrite an env
  # file. It is created with mode 0600 at once, which also shows that its
  # directory is writable before the code is spent.
  defp prepare_token_file!(file) do
    unless outside_repository?(file),
      do: flunk("TEMPO_OAUTH_TOKEN_FILE must be an absolute path outside the repository")

    case File.read(file) do
      {:ok, ""} -> :ok
      {:error, :enoent} -> :ok
      _other -> flunk("TEMPO_OAUTH_TOKEN_FILE must name a missing or empty file")
    end

    File.write!(file, "")
    File.chmod!(file, 0o600)
  end

  defp outside_repository?(file) do
    Path.type(file) == :absolute and
      not String.starts_with?(Path.expand(file) <> "/", @repository <> "/")
  end

  # Writes a temporary file with mode 0600 before any secret goes in, then
  # renames it over the token file, so the previous pair stays readable until
  # the new one is complete.
  defp write_token_file!(file, %{access_token: access, refresh_token: refresh} = token, issued_at) do
    temporary = file <> ".tmp"
    File.write!(temporary, "")
    File.chmod!(temporary, 0o600)

    File.write!(temporary, [
      "TEMPO_OAUTH_ACCESS_TOKEN=#{access}\n",
      "TEMPO_OAUTH_REFRESH_TOKEN=#{refresh}\n",
      expires_at_line(token, issued_at)
    ])

    File.rename!(temporary, file)
  end

  defp write_token_file!(_file, _token, _issued_at), do: flunk("no token pair to write")

  defp expires_at_line(%{expires_in: seconds}, issued_at) when is_integer(seconds) do
    expires_at =
      issued_at |> DateTime.add(seconds, :second) |> DateTime.truncate(:second)

    "TEMPO_OAUTH_ACCESS_TOKEN_EXPIRES_AT=#{DateTime.to_iso8601(expires_at)}\n"
  end

  defp expires_at_line(_token, _issued_at), do: []

  # The recorder redacts token fields by key and checks configured
  # credentials; freshly issued tokens are not configured, so this checks the
  # written fixture for them and for the code.
  defp refute_recorded_secrets!(name, secrets) do
    if LiveSmoke.recording?() do
      path = Path.join([File.cwd!(), "test", "fixtures", "tempo", "recorded", name <> ".json"])
      text = File.read!(path)

      if Enum.any?(secrets, &String.contains?(text, &1)) do
        File.rm!(path)
        flunk("#{name}.json contained a token or the code and was deleted")
      end
    end
  end

  defp oauth_opts(env) do
    [
      client_id: env["TEMPO_OAUTH_CLIENT_ID"],
      client_secret: env["TEMPO_OAUTH_CLIENT_SECRET"],
      redirect_uri: env["TEMPO_OAUTH_REDIRECT_URI"]
    ]
  end

  defp refute_leak(error, secret) do
    leaked? =
      String.contains?(inspect(error), secret) or
        String.contains?(inspect(Error.to_map(error)), secret)

    refute leaked?, "the normalized error contains the token"
  end

  defp request!(env, profile, token, origin \\ nil) do
    field = if profile == :api_token, do: :api_token, else: :access_token

    connection =
      Connection.new!(%{
        id: "tempo_live_#{profile}",
        provider: :tempo,
        profile: profile,
        tenant_id: "live",
        owner_type: :app_user,
        owner_id: "live",
        subject: %{account_id: account_id!(env)},
        status: :connected,
        scopes: [],
        metadata: %{api_origin: origin || env["TEMPO_API_ORIGIN"]}
      })

    case Request.new(connection, %{field => token}) do
      {:ok, request} -> request
      {:error, error} -> flunk("Tempo request rejected: #{inspect(error.reason)}")
    end
  end

  defp account_id!(env) do
    case Req.get(env["JIRA_SITE"] <> "/rest/api/3/myself",
           auth: {:basic, "#{env["JIRA_EMAIL"]}:#{env["JIRA_API_TOKEN"]}"},
           retry: false
         ) do
      {:ok, %{status: 200, body: %{"accountId" => id}}} when is_binary(id) -> id
      _other -> flunk("Jira /rest/api/3/myself did not return an account ID")
    end
  end
end
