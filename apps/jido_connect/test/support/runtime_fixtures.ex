defmodule Jido.Connect.RuntimeFixtures do
  alias Jido.Connect
  alias Jido.Connect.Jido.{ActionProjection, PluginProjection, SensorProjection}

  defmodule ActionHandler do
    def run(%{repo: repo}, _context), do: {:ok, %{repo: repo}}
  end

  defmodule RawErrorHandler do
    def run(_input, _context), do: {:error, :provider_returned_atom}
  end

  defmodule InvalidResultHandler do
    def run(_input, _context), do: :ok
  end

  defmodule ExplodingHandler do
    def run(_input, _context), do: raise("handler exploded")
  end

  defmodule ExplodingScopeResolver do
    def required_scopes(_operation, _input, _connection), do: raise("scope resolver exploded")
  end

  defmodule PollHandler do
    def poll(%{repo: repo}, %{checkpoint: checkpoint}) do
      {:ok, %{signals: [%{repo: repo}], checkpoint: checkpoint || "next"}}
    end
  end

  defmodule BadPollHandler do
    def poll(_config, _context), do: {:ok, %{signals: [%{}], checkpoint: nil}}
  end

  defmodule NonListPollHandler do
    def poll(_config, _context), do: {:ok, %{signals: %{repo: "org/repo"}, checkpoint: nil}}
  end

  defmodule NilSignalsPollHandler do
    def poll(_config, _context), do: {:ok, %{signals: nil, checkpoint: nil}}
  end

  defmodule InvalidEnvelopePollHandler do
    def poll(_config, _context), do: {:ok, nil}
  end

  defmodule AdvancingPollHandler do
    def poll(%{repo: repo}, %{checkpoint: checkpoint}) do
      next_checkpoint =
        case checkpoint do
          nil -> "first"
          "first" -> "second"
          other -> "#{other}:next"
        end

      {:ok, %{signals: [%{repo: "#{repo}:#{next_checkpoint}"}], checkpoint: next_checkpoint}}
    end
  end

  defmodule Integration do
    def integration, do: Jido.Connect.RuntimeFixtures.spec()
  end

  defmodule AdvancingIntegration do
    def integration, do: Jido.Connect.RuntimeFixtures.advancing_poll_spec()
  end

  defmodule InvalidIntegration do
    def integration, do: :not_a_spec
  end

  defmodule RaisingIntegration do
    def integration, do: raise("integration lookup exploded")
  end

  defmodule BadManifestProvider do
    def integration, do: Jido.Connect.RuntimeFixtures.spec()
    def jido_connect_manifest, do: %{id: :bad_manifest}
  end

  defmodule BadModulesProvider do
    def integration, do: Jido.Connect.RuntimeFixtures.spec()
    def jido_connect_modules, do: %{actions: ["not a module"], sensors: [], plugin: nil}
  end

  def spec(overrides \\ %{}) do
    build_spec(
      auth_profiles: [auth_profile()],
      actions: [Map.merge(action_attrs(), Map.get(overrides, :action, %{}))],
      triggers: [Map.merge(trigger_attrs(), Map.get(overrides, :trigger, %{}))]
    )
  end

  def build_spec(attrs) do
    Connect.Spec.new!(%{
      id: :demo,
      name: "Demo",
      auth_profiles: Keyword.get(attrs, :auth_profiles, [auth_profile()]),
      actions:
        attrs
        |> Keyword.get(:actions, [action_attrs()])
        |> Enum.map(&Connect.ActionSpec.new!/1),
      triggers:
        attrs
        |> Keyword.get(:triggers, [trigger_attrs()])
        |> Enum.map(&Connect.TriggerSpec.new!/1)
    })
  end

  def bad_signal_spec do
    build_spec(
      actions: [action_attrs()],
      triggers: [Map.merge(trigger_attrs(), %{handler: BadPollHandler})]
    )
  end

  def non_list_signal_spec do
    build_spec(
      actions: [action_attrs()],
      triggers: [Map.merge(trigger_attrs(), %{handler: NonListPollHandler})]
    )
  end

  def nil_signal_spec do
    build_spec(
      actions: [action_attrs()],
      triggers: [Map.merge(trigger_attrs(), %{handler: NilSignalsPollHandler})]
    )
  end

  def advancing_poll_spec do
    build_spec(
      actions: [action_attrs()],
      triggers: [Map.merge(trigger_attrs(), %{handler: AdvancingPollHandler})]
    )
  end

  def auth_profile do
    Connect.AuthProfile.new!(%{
      id: :user,
      kind: :oauth2,
      owner: :user,
      subject: :user,
      label: "User"
    })
  end

  def action_attrs do
    %{
      id: "demo.repo.show",
      name: :show_repo,
      label: "Show repo",
      description: "Show repo",
      resource: :repo,
      verb: :get,
      data_classification: :workspace_metadata,
      auth_profile: :user,
      handler: ActionHandler,
      input: [field(:repo)],
      output: [field(:repo)],
      input_schema: Zoi.object(%{repo: Zoi.string()}),
      output_schema: Zoi.object(%{repo: Zoi.string()}),
      scopes: ["repo"]
    }
  end

  def trigger_attrs do
    %{
      id: "demo.repo.changed",
      name: :repo_changed,
      kind: :poll,
      label: "Repo changed",
      description: "Repo changed",
      resource: :repo,
      verb: :watch,
      data_classification: :workspace_metadata,
      auth_profile: :user,
      handler: PollHandler,
      config: [field(:repo)],
      signal: [field(:repo)],
      config_schema: Zoi.object(%{repo: Zoi.string()}),
      signal_schema: Zoi.object(%{repo: Zoi.string()}),
      scopes: ["repo"],
      interval_ms: 1_000,
      checkpoint: :updated_at,
      dedupe: %{field: :repo}
    }
  end

  def field(name) do
    Connect.Field.new!(%{name: name, type: :string, required?: true})
  end

  def context_and_lease do
    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :demo,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :user,
        owner_id: "user_1",
        status: :connected,
        scopes: ["repo"]
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second),
        fields: %{}
      })

    {context, lease}
  end

  def action_projection do
    ActionProjection.new!(%{
      module: Integration.Actions.ShowRepo,
      integration_module: Integration,
      integration_id: :demo,
      action_id: "demo.repo.show",
      name: "demo_repo_show",
      label: "Show repo",
      description: "Show repo",
      resource: :repo,
      verb: :get,
      data_classification: :workspace_metadata,
      input: [field(:repo)],
      output: [field(:repo)],
      input_schema: Zoi.object(%{repo: Zoi.string()}),
      output_schema: Zoi.object(%{repo: Zoi.string()}),
      auth_profile: :user,
      scopes: ["repo"],
      risk: :read,
      confirmation: :none
    })
  end

  def sensor_projection do
    SensorProjection.new!(%{
      module: Integration.Sensors.RepoChanged,
      integration_module: Integration,
      integration_id: :demo,
      trigger_id: "demo.repo.changed",
      name: "demo_repo_changed",
      label: "Repo changed",
      description: "Repo changed",
      resource: :repo,
      verb: :watch,
      data_classification: :workspace_metadata,
      kind: :poll,
      runtime_mode: :poll,
      config: [field(:repo)],
      signal: [field(:repo)],
      config_schema: Zoi.object(%{repo: Zoi.string()}),
      signal_schema: Zoi.object(%{repo: Zoi.string()}),
      signal_type: "demo.repo.changed",
      signal_source: "/jido/connect/demo",
      auth_profile: :user,
      scopes: ["repo"],
      interval_ms: 1_000
    })
  end

  def plugin_projection do
    PluginProjection.new!(%{
      module: Integration.Plugin,
      integration_module: Integration,
      integration_id: :demo,
      name: "demo",
      description: "Demo integration tools.",
      actions: [action_projection()],
      sensors: [sensor_projection()]
    })
  end
end
