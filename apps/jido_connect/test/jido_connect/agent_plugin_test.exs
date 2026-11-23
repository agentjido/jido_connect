defmodule Jido.Connect.AgentPluginTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{ConnectionSelector, Context, Error, MCP, Plugin}
  alias Jido.Plugin.Context.Admission
  alias Jido.Plugin.Input

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

  defp action_context(data, provider) do
    selector =
      ConnectionSelector.new!(%{provider: provider, strategy: :explicit, connection_id: "files"})

    context =
      Context.new!(%{tenant_id: "test", actor: %{id: "actor"}, connection_selector: selector})

    admit =
      struct(Admission,
        caller_context: %{
          connect: %{files: %{integration_context: context, credential_lease: :not_accepted}}
        }
      )

    {:ok, runtime} = Plugin.admit(nil, admit, Map.to_list(data))
    %{plugin_inputs: %{Plugin => %Input{runtime: runtime}}}
  end
end
