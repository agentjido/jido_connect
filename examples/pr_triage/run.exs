defmodule PRTriageExample.Flow do
  alias Jido.Connect.GitHub.Actions.GetPullRequest
  alias Jido.Connect.Plugin
  alias Jido.Connect.Slack.Actions.PostMessage
  alias Jido.Joi

  use Jido.Flow,
    name: "triage_pr",
    schema: Joi.object(%{repo: Joi.string(), pull_number: Joi.integer()}),
    output_schema: Joi.object(%{slack_draft: Joi.map()})

  flow do
    step "fetch_pr",
      action: GetPullRequest,
      params: %{repo: input(:repo), pull_number: input(:pull_number)}

    step "draft_slack",
         [
           pr <- result("fetch_pr", :pull_request),
           repo <- input(:repo),
           number <- input(:pull_number)
         ],
         inline: [context: context] do
      if pr[:state] == "open" and pr[:draft] == false do
        with {:ok, _access} <- Plugin.action_context(context, :notifications, PostMessage) do
          {:ok,
           %{channel: context.notification_channel, text: "Ready for review: #{repo}##{number}"}}
        end
      else
        {:ok, %{}}
      end
    end

    output(%{slack_draft: result("draft_slack")})
  end
end

defmodule PRTriageExample.Agent do
  alias Jido.Connect.{GitHub, Slack}
  alias Jido.Joi

  use Jido.Agent, name: "pr_triage", plugins: [Jido.Connect.Plugin]

  state do
    schema(Joi.object(%{slack_draft: Joi.map() |> Joi.default(%{})}))
  end

  connect do
    binding :source, GitHub do
      actions([GitHub.Actions.GetPullRequest])
      triggers(["github.pull_request.updated"])
    end

    binding :notifications, Slack do
      actions([Slack.Actions.PostMessage])
    end
  end

  routes do
    route("github.pull_request.updated", PRTriageExample.Flow)
  end
end

defmodule PRTriageExample.FixtureClient do
  def list_updated_pull_requests("example/widgets", nil, "fixture-github") do
    {:ok,
     [
       %{
         number: 42,
         state: "open",
         title: "Update the widgets",
         url: "https://github.com/example/widgets/pull/42",
         updated_at: "2026-01-01T00:00:00Z"
       }
     ]}
  end

  def get_pull_request("example/widgets", 42, "fixture-github"),
    do: {:ok, %{number: 42, state: "open", draft: false}}

  def post_message(%{channel: "C-REVIEW", text: text}, "fixture-slack"),
    do: {:ok, %{channel: "C-REVIEW", ts: "1.000001", message: %{text: text}}}
end

defmodule PRTriageExample.Host do
  @behaviour Jido.Connect.CredentialResolver

  alias Jido.Connect.{Connection, Context, CredentialLease}
  alias PRTriageExample.FixtureClient

  def action_context(provider, profile, scopes) do
    connection =
      Connection.new!(%{
        id: "fixture/#{provider}",
        provider: provider,
        profile: profile,
        tenant_id: "fixture",
        owner_type: :tenant,
        owner_id: "fixture",
        status: :connected,
        scopes: scopes
      })

    %{
      integration_context:
        Context.new!(%{
          tenant_id: "fixture",
          actor: %{id: "triage", type: :agent},
          connection: connection
        }),
      credential_resolver: __MODULE__,
      policy: __MODULE__
    }
  end

  def authorize(%{id: id}, %{repo: "example/widgets"}, _context, %{provider: :github})
      when id in ["github.pull_request.updated", "github.pull_request.get"],
      do: :ok

  def authorize(%{id: "slack.message.post"}, %{channel: "C-REVIEW"}, _context, %{provider: :slack}),
      do: :ok

  def authorize(_operation, _input, _context, _connection), do: {:error, :target_not_allowed}

  @impl true
  def resolve_lease(%Context{connection: connection} = context, operation_id, input) do
    case authorize(%{id: operation_id}, input, context, connection) do
      :ok ->
        fields =
          case connection.provider do
            :github -> %{access_token: "fixture-github", github_client: FixtureClient}
            :slack -> %{access_token: "fixture-slack", slack_client: FixtureClient}
          end

        {:ok,
         CredentialLease.from_connection!(connection, fields,
           expires_at: DateTime.add(DateTime.utc_now(), 300)
         )}

      {:error, reason} ->
        {:error, Jido.Connect.Error.auth("Fixture access denied", reason: reason)}
    end
  end
end

defmodule PRTriageExample do
  alias Jido.Connect
  alias Jido.Connect.GitHub.Sensors.UpdatedPullRequests
  alias Jido.Connect.Slack
  alias PRTriageExample.{Agent, Host}

  def run do
    github = Host.action_context(:github, :user, ["repo"])
    slack = Host.action_context(:slack, :bot, ["chat:write"])

    {:ok, instance} = Jido.start_link(name: __MODULE__, namespace: "examples/pr-triage")

    try do
      {:ok, server} = Jido.start_agent(__MODULE__, Agent, id: "triage")
      :ok = Jido.AgentServer.await_ready(server)

      {:ok, watch, [{:schedule, _interval}]} =
        UpdatedPullRequests.init(%{repo: "example/widgets"}, github)

      {:ok, _watch, [{:emit, signal}, {:schedule, _interval}]} =
        UpdatedPullRequests.handle_event(:tick, watch)

      {:ok, %{status: :committed}} =
        Jido.AgentServer.call(server, signal,
          context: %{
            connect: %{source: github, notifications: slack},
            notification_channel: "C-REVIEW"
          }
        )

      %{agent: %{state: %{slack_draft: draft}}} = Jido.AgentServer.snapshot(server)
      %{channel: "C-REVIEW", text: "Ready for review: example/widgets#42"} = draft

      post_fixture(draft, slack)
    after
      Supervisor.stop(instance)
    end
  end

  defp post_fixture(draft, slack) do
    operation = "slack.message.post"
    context = slack.integration_context
    {:ok, lease} = Host.resolve_lease(context, operation, draft)
    opts = %{context: context, credential_lease: lease, policy: Host}
    {:ok, prepared} = Connect.prepare(Slack, operation, draft, opts)
    true = prepared.confirmation_required?

    # This one-use approval exists only in the offline fixture.
    approval = make_ref()
    {:ok, approvals} = Elixir.Agent.start_link(fn -> %{approval => prepared.id} end)

    try do
      validate = fn evidence, candidate, _context ->
        Elixir.Agent.get_and_update(approvals, fn pending ->
          if Map.get(pending, evidence) == candidate.id do
            {:ok, Map.delete(pending, evidence)}
          else
            {{:error, :fixture_approval_invalid}, pending}
          end
        end)
      end

      commit_opts =
        Map.merge(opts, %{execution_authorization: approval, authorization_validator: validate})

      {:ok, %{message: %{text: text}}} = Connect.commit(Slack, prepared, draft, commit_opts)

      {:error, %Connect.Error.AuthError{reason: :invalid_execution_authorization}} =
        Connect.commit(Slack, prepared, draft, commit_opts)

      IO.puts(text)
    after
      Elixir.Agent.stop(approvals)
    end
  end
end

PRTriageExample.run()
