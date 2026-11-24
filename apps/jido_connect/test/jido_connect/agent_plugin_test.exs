defmodule Jido.Connect.AgentPluginTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{ConnectionSelector, Context, Error, MCP, Plugin}
  alias Jido.Plugin.Context.Admission
  alias Jido.Plugin.Input

  defmodule Resolver do
    @behaviour Jido.Connect.CredentialResolver

    @impl true
    def resolve_lease(_context, _action, _input), do: {:error, Error.auth("Denied")}
  end

  defmodule Agent do
    use Jido.Agent, name: "connect_binding_test", plugins: [Plugin]

    state do
      schema(Jido.Joi.object(%{}))
    end

    connect do
      binding :files, MCP do
        actions [MCP.Actions.ReadResource]
      end
    end
  end

  test "lowers named bindings and checks selections against the connector manifest" do
    assert [%{provider: Plugin, data: config}] = Agent.definition().plugins

    assert %{
             bindings: [
               %{name: :files, integration: MCP, actions: [MCP.Actions.ReadResource]} = binding
             ]
           } = config

    assert {:error, :duplicate_connect_binding} =
             Plugin.normalize(%{bindings: [binding, binding]})

    assert {:error, {:invalid_connect_selection, :files, MCP}} =
             Plugin.normalize(%{bindings: [%{binding | triggers: ["mcp.unknown"]}]})

    assert {:error, {:invalid_connect_selection, :files, MCP}} =
             Plugin.normalize(%{bindings: [%{binding | credential_resolver: String}]})

    original = %{bindings: [Map.take(binding, [:name, :integration, :actions, :triggers])]}
    assert {:ok, ^original} = Plugin.normalize(original)
  end

  test "requires the selected Action and a matching live provider binding" do
    [%{data: data}] = Agent.definition().plugins

    context = action_context(data, :mcp)

    assert {:ok, %{integration_context: %Context{}} = opts} =
             Plugin.action_context(context, :files, MCP.Actions.ReadResource)

    refute Map.has_key?(opts, :credential_lease)

    assert {:error, %Error.ConfigError{}} =
             Plugin.action_context(context, :files, MCP.Actions.ListTools)

    assert {:error, %Error.ConfigError{}} =
             Plugin.action_context(context, :other, MCP.Actions.ReadResource)

    assert {:error, %Error.ConfigError{}} =
             data
             |> action_context(:github)
             |> Plugin.action_context(:files, MCP.Actions.ReadResource)
  end

  test "selects a binding by Signal type and uses the declared credential resolver" do
    [%{data: %{bindings: [binding]}}] = Agent.definition().plugins

    data = %{
      bindings: [
        %{binding | signals: ["read.files"], credential_resolver: Resolver},
        %{binding | name: :media, signals: ["read.media"]}
      ]
    }

    action = MCP.Actions.ReadResource

    assert {:ok, %{credential_resolver: Resolver}} =
             data |> action_context(:mcp, "read.files") |> Plugin.action_context(action)

    assert {:error, %Error.ConfigError{details: %{binding: :media}}} =
             data |> action_context(:mcp, "read.media") |> Plugin.action_context(action)

    assert {:error, %Error.ConfigError{details: %{bindings: [], signal_type: "read.other"}}} =
             data |> action_context(:mcp, "read.other") |> Plugin.action_context(action)
  end

  test "rejects overlapping bindings even when only one has a live context" do
    [%{data: %{bindings: [binding]}}] = Agent.definition().plugins
    data = %{bindings: [binding, %{binding | name: :media}]}

    assert {:error, %Error.ConfigError{details: %{bindings: [:files, :media]}}} =
             data
             |> action_context(:mcp)
             |> Plugin.action_context(MCP.Actions.ReadResource)
  end

  test "admission uses the host context and a declared resolver ahead of the context resolver" do
    [%{data: %{bindings: [binding]}}] = Agent.definition().plugins
    {host_context, _lease} = Jido.Connect.RuntimeFixtures.context_and_lease()

    context = %{
      host_context
      | connection: %{host_context.connection | provider: :mcp},
        credential_resolver: __MODULE__
    }

    signal =
      Jido.Signal.new!(%{
        type: "read.files",
        source: "/test/connect",
        data: %{connect: %{files: %{credential_resolver: String}}}
      })

    action = MCP.Actions.ReadResource

    assert {:ok, %{integration_context: ^context}} =
             %{bindings: [binding]}
             |> admit(%{files: context}, signal)
             |> Plugin.action_context(action)

    assert {:ok, %{integration_context: ^context, credential_resolver: Resolver}} =
             %{bindings: [%{binding | credential_resolver: Resolver}]}
             |> admit(%{files: context}, signal)
             |> Plugin.action_context(:files, action)

    assert {:error, %Error.ConfigError{details: %{binding: :files}}} =
             %{bindings: [binding]}
             |> admit(%{}, signal)
             |> Plugin.action_context(action)
  end

  defp action_context(data, provider, signal_type \\ "read.files") do
    selector =
      ConnectionSelector.new!(%{provider: provider, strategy: :explicit, connection_id: "files"})

    context =
      Context.new!(%{tenant_id: "test", actor: %{id: "actor"}, connection_selector: selector})

    signal = Jido.Signal.new!(%{type: signal_type, source: "/test/connect"})

    admit(
      data,
      %{
        files: %{
          integration_context: context,
          credential_resolver: :from_host,
          credential_lease: :not_accepted
        }
      },
      signal
    )
  end

  defp admit(data, contexts, signal) do
    admission = struct(Admission, signal: signal, caller_context: %{connect: contexts})
    {:ok, runtime} = Plugin.admit(nil, admission, Map.to_list(data))
    %{plugin_inputs: %{Plugin => %Input{runtime: runtime}}}
  end
end
