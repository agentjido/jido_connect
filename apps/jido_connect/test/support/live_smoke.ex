Code.require_file("live_smoke/sanitize.ex", __DIR__)
Code.require_file("live_smoke/recorder.ex", __DIR__)

defmodule Jido.Connect.TestSupport.LiveSmoke do
  @moduledoc """
  Live smoke convention for provider test accounts.

  Live tests carry the `:live_smoke` tag. Test helpers exclude it, so a plain
  `mix test` never calls a provider; `mix test --only live_smoke` runs them.
  Credentials and test data IDs come from environment variables, listed with
  the rest of the convention in `docs/live_smoke_tests.md`.

      defmodule Jido.Connect.Slack.LiveSmokeTest do
        use ExUnit.Case, async: false
        use Jido.Connect.TestSupport.LiveSmoke

        @tag env!(["SLACK_BOT_TOKEN"])
        test "auth.test accepts the bot token", %{env: env} do
          LiveSmoke.record({:jido_connect_slack, :slack_req_options}, :slack, "auth_test")
          assert {:ok, _identity} = Jido.Connect.Slack.Client.auth_test(env["SLACK_BOT_TOKEN"])
        end

        @tag env!(["SLACK_BOT_TOKEN", "SLACK_PUBLIC_CHANNEL_ID"])
        @tag write!(:slack)
        test "posts and deletes a message", %{env: env} do
          ...
        end
      end

  `env!/1` and `write!/1` are evaluated when the test file compiles, which is
  when `mix test` runs, so a missing variable or a closed write gate turns into
  an ExUnit skip that names the variable.
  """

  alias Jido.Connect.TestSupport.LiveSmoke.{Recorder, Sanitize}

  @variables %{
    google: %{
      credentials: ~w(GOOGLE_CLIENT_SECRET GOOGLE_REFRESH_TOKEN GOOGLE_ACCESS_TOKEN
                      GOOGLE_GMAIL_METADATA_REFRESH_TOKEN GOOGLE_GMAIL_METADATA_ACCESS_TOKEN),
      settings: ~w(GOOGLE_CLIENT_ID GOOGLE_GMAIL_QUERY GOOGLE_GMAIL_THREAD_ID
                   GOOGLE_GMAIL_ATTACHMENT_MESSAGE_ID GOOGLE_GMAIL_FORWARD_INLINE_ID
                   GOOGLE_GMAIL_FORWARD_ATTACHED_ID GOOGLE_GMAIL_FORWARD_OPAQUE_ID
                   GOOGLE_GMAIL_FORWARD_RELATED_ID GOOGLE_GMAIL_FORWARD_UNTITLED_ID
                   GOOGLE_GMAIL_CHARSET_MESSAGE_ID GOOGLE_GMAIL_LARGE_BODY_ID
                   GOOGLE_GMAIL_UNNAMED_ATTACHMENT_MESSAGE_ID
                   GOOGLE_GMAIL_CLIENT_FORWARD_OUTLOOK_INLINE_ID
                   GOOGLE_GMAIL_CLIENT_FORWARD_OUTLOOK_ATTACHED_ID
                   GOOGLE_GMAIL_CLIENT_FORWARD_GMAIL_INLINE_ID
                   GOOGLE_GMAIL_CLIENT_FORWARD_GMAIL_ATTACHED_ID GOOGLE_GMAIL_LABEL_ID
                   GOOGLE_GMAIL_DISPOSABLE_MESSAGE_ID GOOGLE_GMAIL_RECIPIENT GOOGLE_CALENDAR_ID
                   GOOGLE_CALENDAR_EVENT_ID GOOGLE_CALENDAR_AGENDA_FILE_ID
                   GOOGLE_CALENDAR_HANDOUT_URL GOOGLE_CALENDAR_CONFERENCE_ID
                   GOOGLE_MEET_CONFERENCE_RECORD GOOGLE_MEET_TRANSCRIPT
                   GOOGLE_MEET_RECORDING GOOGLE_MEET_RECORDING_FILE_ID
                   GOOGLE_MEET_NOTES_DOCUMENT_ID GOOGLE_DRIVE_SHARED_LINK_URL
                   GOOGLE_DRIVE_SHORTCUT_ID
                   GOOGLE_DOCS_TABBED_DOCUMENT_ID GOOGLE_DRIVE_STARRED_FILE_ID
                   GOOGLE_DRIVE_FOLDER_ID GOOGLE_DRIVE_WATCH_FOLDER_ID
                   GOOGLE_DRIVE_UPLOAD_FOLDER_ID GOOGLE_DOCS_SCRATCH_DOCUMENT_ID
                   GOOGLE_GMAIL_ARCHIVE_MESSAGE_ID GOOGLE_DRIVE_EDIT_FILE_ID
                   GOOGLE_DRIVE_DELETE_FILE_ID GOOGLE_MEET_POLL_EVENT_ID GOOGLE_TEST_USER
                   GOOGLE_CLOUD_PROJECT GOOGLE_SEED_ATTENDEES)
    },
    slack: %{
      credentials: ~w(SLACK_BOT_TOKEN SLACK_SIGNING_SECRET SLACK_USER_TOKEN),
      settings: ~w(SLACK_PUBLIC_CHANNEL_ID SLACK_PRIVATE_CHANNEL_ID SLACK_DM_CHANNEL_ID
                   SLACK_MPIM_CHANNEL_ID SLACK_NO_ACCESS_CHANNEL_ID SLACK_THREAD_TS
                   SLACK_SECOND_USER_ID SLACK_CAPTURE_DIR SLACK_APP_ID)
    },
    jira: %{
      credentials: ~w(JIRA_API_TOKEN JIRA_WEBHOOK_SECRET SEED_ADMIN_API_TOKEN),
      settings: ~w(JIRA_SITE JIRA_EMAIL JIRA_PROJECT_KEY JIRA_ISSUE_KEY JIRA_ISSUE_ID
                   JIRA_CAPTURE_DIR SEED_ADMIN_EMAIL)
    },
    tempo: %{
      credentials: ~w(TEMPO_API_TOKEN TEMPO_OAUTH_CLIENT_SECRET TEMPO_OAUTH_ACCESS_TOKEN
                      TEMPO_OAUTH_REFRESH_TOKEN TEMPO_OAUTH_CODE SEED_TEMPO_API_TOKEN),
      settings: ~w(TEMPO_OAUTH_CLIENT_ID TEMPO_OAUTH_REDIRECT_URI TEMPO_API_ORIGIN
                   TEMPO_ACCOUNT_ID TEMPO_JIRA_ISSUE_ID TEMPO_JIRA_PROJECT_ID
                   TEMPO_OAUTH_ACCESS_TOKEN_EXPIRES_AT TEMPO_OAUTH_TOKEN_FILE
                   TEMPO_WORK_ATTRIBUTES)
    },
    confluence: %{
      credentials: ~w(CONFLUENCE_API_TOKEN),
      settings: ~w(CONFLUENCE_SITE CONFLUENCE_EMAIL CONFLUENCE_PAGE_ID CONFLUENCE_RICH_PAGE_ID
                   CONFLUENCE_RESTRICTED_PAGE_ID)
    }
  }

  @replay_secret "jido-connect-live-smoke-replay-secret"

  # Settings whose URL host names a customer site or a developer's tunnel.
  @host_variables ~w(JIRA_SITE CONFLUENCE_SITE TEMPO_OAUTH_REDIRECT_URI JIDO_PUBLIC_URL)
  @loopback_hosts ~w(localhost 127.0.0.1 ::1)

  defmacro __using__(_opts) do
    quote do
      alias Jido.Connect.TestSupport.LiveSmoke
      import Jido.Connect.TestSupport.LiveSmoke, only: [env!: 1, write!: 1]

      @moduletag :live_smoke
      setup {Jido.Connect.TestSupport.LiveSmoke, :setup_live_env}
    end
  end

  @doc "Returns the variables of the convention by provider."
  @spec variables() :: %{atom() => %{credentials: [String.t()], settings: [String.t()]}}
  def variables, do: @variables

  @doc """
  Returns tags for a test that reads `names` from the environment.

  An unset or empty variable adds a `:skip` tag naming it. ExUnit does not
  print skip reasons, so a run that includes `:live_smoke` also prints the
  reason with the test's file and line. The setup from `use LiveSmoke` puts
  the values into the test context under `:env`.
  """
  defmacro env!(names) do
    quote do
      Jido.Connect.TestSupport.LiveSmoke.env_tags(unquote(names), __ENV__)
    end
  end

  @doc """
  Returns tags for a test that writes to the provider account.

  The test is skipped unless `<PROVIDER>_LIVE_DESTRUCTIVE=true`.
  """
  defmacro write!(provider) do
    quote do
      Jido.Connect.TestSupport.LiveSmoke.write_tags(unquote(provider), __ENV__)
    end
  end

  @doc false
  @spec env_tags([String.t()], Macro.Env.t()) :: keyword()
  def env_tags(names, env) when is_list(names) do
    Enum.each(names, &known_variable!/1)

    case Enum.filter(names, &blank?(System.get_env(&1))) do
      [] ->
        [live_env: names]

      missing ->
        [
          live_env: names,
          skip: skip_reason("set #{Enum.join(missing, ", ")} to run this live test", env)
        ]
    end
  end

  @doc false
  @spec write_tags(atom(), Macro.Env.t()) :: keyword()
  def write_tags(provider, env) do
    variable = destructive_variable!(provider)

    if System.get_env(variable) == "true" do
      [live_write: provider]
    else
      [
        live_write: provider,
        skip: skip_reason("set #{variable}=true to run this live write", env)
      ]
    end
  end

  @doc false
  def setup_live_env(context) do
    check_write_gate!(context[:live_write])

    case context[:live_env] do
      nil -> :ok
      names -> %{env: Map.new(names, &{&1, fetch_env!(&1)})}
    end
  end

  @doc "Returns whether `JIDO_CONNECT_RECORD=1` asks to record provider responses."
  @spec recording?() :: boolean()
  def recording?, do: System.get_env("JIDO_CONNECT_RECORD") == "1"

  @doc """
  Records the responses of the current test when `JIDO_CONNECT_RECORD=1`.

  `target` names a package's Req options, such as
  `{:jido_connect_slack, :slack_req_options}`. The recorder joins them as the
  Req adapter until the test exits and writes each response, sanitized, to
  `test/fixtures/<provider>/recorded/<name>.json`; later responses of the same
  test go to `<name>.2.json`, `<name>.3.json` and so on.

  Options are `:root` (default: the current directory), `:transform` and the
  sanitizer options of `sanitize/2`. Without `JIDO_CONNECT_RECORD=1` this
  does nothing.

  `:transform` is a function of the decoded request path and the decoded
  response body. It returns the body to record, or `:skip` to write no
  fixture for that response; a skipped response takes no number. It runs
  before the sanitizer, whose leak guard checks its result, and it changes
  only the fixture, never the response the caller gets. Use it to leave out
  or neutralize data that a shared test account returns besides the test
  data, such as other users' entries, and say in the test what it changes.
  A fixture whose body the transform changed carries `"transformed": true`;
  its headers, such as `content-length`, still describe the provider's
  response.
  """
  @spec record({atom(), atom()}, atom() | String.t(), String.t(), keyword()) :: :ok
  def record({app, key}, provider, name, opts \\ []) when is_atom(app) and is_atom(key) do
    if recording?() do
      {transform, opts} = Keyword.pop(opts, :transform)
      check_transform!(transform)
      patch_req_options!(app, key)

      session = %{
        dir: fixture_dir(provider, :recorded, opts),
        name: name,
        count: 0,
        transform: transform,
        sanitizer: sanitizer(opts)
      }

      case Process.whereis(Recorder) do
        nil -> ExUnit.Callbacks.start_supervised!({Recorder, session})
        _pid -> Recorder.switch(session)
      end
    end

    :ok
  end

  @doc """
  Returns the body of a recorded fixture, unchanged, for `Req.Test.json/2`.

      Req.Test.stub(MyStub, &Req.Test.json(&1, LiveSmoke.fixture!(:slack, "auth_test")))
  """
  @spec fixture!(atom() | String.t(), String.t(), keyword()) :: term()
  def fixture!(provider, name, opts \\ []) do
    provider
    |> fixture_dir(:recorded, opts)
    |> Path.join("#{name}.json")
    |> File.read!()
    |> Jason.decode!()
    |> Map.fetch!("body")
  end

  @doc """
  Sanitizes a decoded provider value.

  Redacts the sensitive keys of `Jido.Connect.Sanitizer` except `:keep_keys`
  (default `["fields"]`, the issue payload of Jira), replaces email addresses,
  display names, site and tunnel hosts, Atlassian account IDs and the Google
  project number with stable placeholders, and replaces the values under
  `:fields` with `<field>-<n>`. `:name_keys` adds keys that hold display names.
  Raises `LeakError` when a credential value, a configured host or email
  address, the Google project number, or a replaced host or account ID
  remains.
  """
  @spec sanitize(term(), keyword()) :: term()
  def sanitize(value, opts \\ []) do
    {sanitized, state} = Sanitize.value(value, sanitizer(opts))
    Sanitize.check_leaks!(sanitized, state)
    sanitized
  end

  @doc "Drops auth, cookie, signature and forwarding headers and sanitizes the rest."
  @spec sanitize_headers(map() | [{String.t(), term()}], keyword()) :: map()
  def sanitize_headers(headers, opts \\ []) do
    {sanitized, state} = Sanitize.headers(headers, sanitizer(opts))
    Sanitize.check_leaks!(sanitized, state)
    sanitized
  end

  @doc """
  Sanitizes a captured delivery and signs it again with `replay_secret/0`.

  `capture` is a capture map or the path of a capture file from the demo
  host. Slack and Jira captures need the provider's signing secret as
  `:secret`: the original signature must verify before the sanitized body
  gets a new `x-slack-signature` or `x-hub-signature`. A forged or edited
  capture therefore never becomes a fixture. The capture's `Host` header,
  usually the tunnel, is replaced like a configured site host. Other options
  are those of `sanitize/2`.
  """
  @spec sanitize_capture(map() | Path.t(), keyword()) :: map()
  def sanitize_capture(capture, opts \\ []) do
    capture = load_capture(capture)
    {secret, opts} = Keyword.pop(opts, :secret)
    verify_capture!(capture, secret)
    state = sanitizer(opts, capture_hosts(capture))
    content_type = Sanitize.header_value_of(capture["headers"], "content-type")

    {body, state} = Sanitize.body(capture["body"], content_type, state)
    {headers, state} = Sanitize.headers(capture["headers"], state)
    {path, state} = Sanitize.text(capture["path"] || "", state)

    sanitized =
      Map.merge(capture, %{
        "body" => body,
        "headers" => resign(capture["provider"], body, headers),
        "path" => path
      })

    Sanitize.check_leaks!(sanitized, state)
    sanitized
  end

  @doc """
  Sanitizes a capture and writes it to `test/fixtures/<provider>/captured/<name>.json`.

  Returns the written path. Accepts `:root`, `:secret` and the options of
  `sanitize/2`; see `sanitize_capture/2`.
  """
  @spec write_capture!(map() | Path.t(), atom() | String.t(), String.t(), keyword()) :: Path.t()
  def write_capture!(capture, provider, name, opts \\ []) do
    sanitized = sanitize_capture(capture, opts)
    dir = fixture_dir(provider, :captured, opts)
    path = Path.join(dir, "#{name}.json")

    File.mkdir_p!(dir)
    File.write!(path, [Jason.encode_to_iodata!(sanitized, pretty: true), "\n"])
    path
  end

  @doc """
  Passes a capture through `webhook.verify_delivery/4`.

  The captured time is the verifier's `:now`. Options: `:webhook` (required),
  `:secret` (default `replay_secret/0`, the key of sanitized captures); the
  rest goes to `verify_delivery/4`.
  """
  @spec replay(map() | Path.t(), keyword()) :: term()
  def replay(capture, opts) do
    capture = load_capture(capture)
    {webhook, opts} = Keyword.pop!(opts, :webhook)
    {secret, opts} = Keyword.pop(opts, :secret, @replay_secret)

    webhook.verify_delivery(
      capture["body"],
      capture["headers"],
      secret,
      Keyword.put(opts, :now, capture["captured_at"])
    )
  end

  @doc "Returns the signing secret of sanitized captures."
  @spec replay_secret() :: String.t()
  def replay_secret, do: @replay_secret

  defp skip_reason(reason, env) do
    include = ExUnit.configuration()[:include] || []

    if Enum.any?(include, &(&1 == :live_smoke or match?({:live_smoke, _value}, &1))) do
      IO.puts("live_smoke skip #{Path.relative_to_cwd(env.file)}:#{env.line}: #{reason}")
    end

    reason
  end

  defp known_variable!(name) do
    known? =
      Enum.any?(@variables, fn {_provider, groups} ->
        name in groups.credentials or name in groups.settings
      end)

    unless known? do
      raise ArgumentError,
            "#{name} is not a live smoke variable; add it to LiveSmoke and docs/live_smoke_tests.md"
    end
  end

  defp destructive_variable!(provider) when is_map_key(@variables, provider),
    do: "#{provider |> Atom.to_string() |> String.upcase()}_LIVE_DESTRUCTIVE"

  defp destructive_variable!(provider) do
    raise ArgumentError,
          "#{inspect(provider)} is not a live smoke provider; use one of " <>
            inspect(Map.keys(@variables))
  end

  defp check_write_gate!(nil), do: :ok
  defp check_write_gate!(false), do: :ok

  defp check_write_gate!(provider) when is_atom(provider) and is_map_key(@variables, provider) do
    variable = destructive_variable!(provider)

    unless System.get_env(variable) == "true" do
      raise ArgumentError, "set #{variable}=true to run this live write"
    end
  end

  defp check_write_gate!(_tag) do
    raise ArgumentError, "tag live writes with write!/1 so the provider's gate applies"
  end

  defp check_transform!(nil), do: :ok
  defp check_transform!(transform) when is_function(transform, 2), do: :ok

  defp check_transform!(_transform) do
    raise ArgumentError, ":transform must be a function of the request path and the body"
  end

  defp patch_req_options!(app, key) do
    previous = Application.fetch_env(app, key)
    options = with {:ok, options} <- previous, do: options, else: (_error -> [])

    if Keyword.has_key?(options, :plug) do
      raise ArgumentError,
            "remove :plug from #{inspect(app)} #{inspect(key)} to record live responses"
    end

    unless options[:adapter] == Recorder do
      Application.put_env(app, key, Keyword.put(options, :adapter, Recorder))
      ExUnit.Callbacks.on_exit(fn -> restore_env(app, key, previous) end)
    end
  end

  defp restore_env(app, key, {:ok, options}), do: Application.put_env(app, key, options)
  defp restore_env(app, key, :error), do: Application.delete_env(app, key)

  defp sanitizer(opts, extra_hosts \\ []) do
    opts
    |> Keyword.put(:credentials, credential_values())
    |> Keyword.put(:hosts, configured_hosts() ++ extra_hosts)
    |> Keyword.put(:identifying, configured_emails())
    |> Keyword.put(:project_numbers, project_numbers())
    |> Sanitize.new()
  end

  # Gmail's Received headers name the Cloud project of the OAuth client by its
  # number, the numeric prefix of `<number>-<id>.apps.googleusercontent.com`.
  defp project_numbers do
    case Regex.run(~r/^(\d+)-/, System.get_env("GOOGLE_CLIENT_ID") || "") do
      [_match, number] -> [{"the Google project number", number}]
      nil -> []
    end
  end

  # Listed settings and every set variable ending in _EMAIL whose value is an address.
  defp configured_emails do
    listed = for {_provider, groups} <- @variables, name <- groups.settings, do: name
    shaped = for {name, _value} <- System.get_env(), String.ends_with?(name, "_EMAIL"), do: name

    for name <- Enum.uniq(listed ++ shaped),
        value = System.get_env(name),
        not blank?(value) and Regex.match?(~r/^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$/, value),
        do: {name, value}
  end

  defp configured_hosts do
    for name <- @host_variables,
        value = System.get_env(name),
        not blank?(value),
        host = URI.parse(value).host,
        not blank?(host) and host not in @loopback_hosts,
        do: {name, host}
  end

  # The demo host receives captures through a tunnel, so the Host header names it.
  defp capture_hosts(capture) do
    host =
      capture["headers"]
      |> Sanitize.header_value_of("host")
      |> String.replace(~r/:\d+$/, "")

    if blank?(host) or host in @loopback_hosts, do: [], else: [{"the capture host", host}]
  end

  # Listed credentials plus every set variable whose name looks like one, so a
  # token added to an env file before it is listed here is still guarded.
  defp credential_values do
    listed = for {_provider, groups} <- @variables, name <- groups.credentials, do: name

    shaped =
      for {name, _value} <- System.get_env(),
          Regex.match?(~r/(TOKEN|SECRET|PASSWORD|API_KEY)$/, name),
          do: name

    for name <- Enum.uniq(listed ++ shaped),
        value = System.get_env(name),
        not blank?(value),
        do: {name, value}
  end

  defp fixture_dir(provider, kind, opts) do
    Path.join([
      Keyword.get(opts, :root, File.cwd!()),
      "test",
      "fixtures",
      to_string(provider),
      to_string(kind)
    ])
  end

  defp load_capture(path) when is_binary(path), do: path |> File.read!() |> Jason.decode!()
  defp load_capture(capture) when is_map(capture), do: capture

  defp verify_capture!(capture, secret) do
    provider = capture["provider"]
    headers = capture["headers"] || %{}

    case signature(provider, secret || "", capture["body"] || "", headers) do
      nil ->
        :ok

      {_header, _expected} when secret in [nil, ""] ->
        raise ArgumentError,
              "pass the #{provider} signing secret as :secret to sanitize a capture"

      {header, expected} ->
        unless Sanitize.header_value_of(headers, header) == expected do
          raise ArgumentError, "the #{provider} capture signature does not verify with :secret"
        end
    end
  end

  defp resign(provider, body, headers) do
    case signature(provider, @replay_secret, body, headers) do
      nil -> headers
      {header, value} -> Map.put(headers, header, value)
    end
  end

  # The signature header of a delivery and its value under `secret`.
  defp signature("slack", secret, body, headers) do
    timestamp = Sanitize.header_value_of(headers, "x-slack-request-timestamp")
    {"x-slack-signature", "v0=" <> hmac(secret, "v0:#{timestamp}:#{body}")}
  end

  defp signature("jira", secret, body, _headers),
    do: {"x-hub-signature", "sha256=" <> hmac(secret, body)}

  defp signature(_provider, _secret, _body, _headers), do: nil

  defp hmac(secret, data) do
    :hmac
    |> :crypto.mac(:sha256, secret, data)
    |> Base.encode16(case: :lower)
  end

  defp fetch_env!(name) do
    case System.get_env(name) do
      value when value in [nil, ""] -> raise ArgumentError, "set #{name} to run this live test"
      value -> value
    end
  end

  defp blank?(value), do: value in [nil, ""]
end
