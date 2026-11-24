defmodule Jido.Connect.Examples.StartHere.Host do
  @moduledoc "Supplies named Connect bindings and controls access to example targets."
  @behaviour Jido.Connect.CredentialResolver

  alias Jido.Connect.{Connection, Context, CredentialLease, Error}
  alias Jido.Connect.Examples.StartHere.Fixture

  def github(repo, mode) do
    binding(:github, :user, ["repo"], repo, credential_ref(:github, mode))
  end

  def slack(channel, mode) do
    binding(:slack, :bot, ["channels:read"], channel, credential_ref(:slack, mode))
  end

  def with_agent(agent, fun) do
    name = agent
    namespace = "examples/connect/#{System.unique_integer([:positive])}"
    {:ok, runtime} = Jido.start_link(name: name, namespace: namespace)

    try do
      {:ok, server} = Jido.start_agent(name, agent, id: "connect")
      :ok = Jido.AgentServer.await_ready(server)
      fun.(server)
    after
      Supervisor.stop(runtime)
    end
  end

  def call(server, signal, context) do
    case Jido.AgentServer.call(server, signal, context: context, timeout: 20_000) do
      {:ok, %{status: :committed}} -> {:ok, Jido.AgentServer.snapshot(server).agent.state}
      {:ok, %{status: status, error: error}} -> {:error, error || status}
      {:error, _reason} = error -> error
    end
  end

  def authorize(%{id: id}, %{repo: repo}, %Context{claims: %{target: target}}, %{
        provider: :github
      })
      when id in ["github.pull_request.get", "github.pull_request.updated"] and repo == target,
      do: :ok

  def authorize(
        %{id: "slack.conversation.info"},
        %{channel: channel},
        %Context{claims: %{target: target}},
        %{
          provider: :slack
        }
      )
      when channel == target,
      do: :ok

  def authorize(_operation, _input, _context, _connection), do: {:error, :target_not_allowed}

  @impl true
  def resolve_lease(%Context{connection: connection} = context, operation_id, input) do
    with :ok <- authorize(%{id: operation_id}, input, context, connection),
         {:ok, fields} <- credential_fields(connection) do
      CredentialLease.from_connection(connection, fields,
        expires_at: DateTime.add(DateTime.utc_now(), 60)
      )
    else
      {:error, reason} -> {:error, Error.auth("Example credential access denied", reason: reason)}
    end
  end

  def required_env!(name) do
    case System.get_env(name) do
      value when is_binary(value) and value != "" -> value
      _other -> raise "Set #{name} before running the live example."
    end
  end

  def repo(:fixture), do: "example/widgets"

  def repo(:live) do
    repo = required_env!("GITHUB_REPO")

    unless Regex.match?(~r{\A[a-zA-Z0-9-]+/[a-zA-Z0-9_.-]+\z}, repo) do
      raise "Set GITHUB_REPO to a repository in owner/repo form."
    end

    repo
  end

  def pull_number(:fixture), do: 42

  def pull_number(:live) do
    case Integer.parse(required_env!("GITHUB_PR_NUMBER")) do
      {number, ""} when number > 0 -> number
      _other -> raise "Set GITHUB_PR_NUMBER to a positive integer."
    end
  end

  def live_mode!(providers) do
    case System.argv() do
      [] ->
        :fixture

      ["--live"] ->
        Enum.each(providers, &required_env!(credential_ref(&1, :live)))
        :live

      _other ->
        raise "Run with no arguments for the fixture or with --live for external reads."
    end
  end

  def print!({:ok, value}), do: IO.inspect(value, pretty: true)

  def print!({:error, reason}),
    do: raise("Example failed: #{inspect(Jido.Connect.Sanitizer.sanitize(reason, :transport))}")

  defp binding(provider, profile, scopes, target, credential_ref) do
    connection =
      Connection.new!(%{
        id: "example/#{provider}",
        provider: provider,
        profile: profile,
        tenant_id: "example",
        owner_type: :tenant,
        owner_id: "example",
        credential_ref: credential_ref,
        status: :connected,
        scopes: scopes
      })

    %{
      integration_context:
        Context.new!(%{
          tenant_id: "example",
          actor: %{id: "connect-example", type: :agent},
          claims: %{target: target},
          connection: connection
        }),
      credential_resolver: __MODULE__,
      policy: __MODULE__,
      request_timeout_ms: 10_000
    }
  end

  defp credential_ref(:github, :fixture), do: "fixture/github"
  defp credential_ref(:slack, :fixture), do: "fixture/slack"
  defp credential_ref(:github, :live), do: "GITHUB_TOKEN"
  defp credential_ref(:slack, :live), do: "SLACK_BOT_TOKEN"

  defp credential_fields(%{provider: :github, credential_ref: "fixture/github"}),
    do: {:ok, %{access_token: "fixture-github", github_client: Fixture}}

  defp credential_fields(%{provider: :slack, credential_ref: "fixture/slack"}),
    do: {:ok, %{access_token: "fixture-slack", slack_client: Fixture}}

  defp credential_fields(%{provider: :github, credential_ref: "GITHUB_TOKEN"}) do
    {:ok,
     %{access_token: required_env!("GITHUB_TOKEN"), github_client: Jido.Connect.GitHub.Client}}
  end

  defp credential_fields(%{provider: :slack, credential_ref: "SLACK_BOT_TOKEN"}),
    do:
      {:ok,
       %{access_token: required_env!("SLACK_BOT_TOKEN"), slack_client: Jido.Connect.Slack.Client}}

  defp credential_fields(_connection), do: {:error, :unknown_credential_ref}
end
