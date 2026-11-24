defmodule Jido.Connect.Plugin do
  @moduledoc """
  Declares named connector bindings on a Jido v3 Agent.

  Use a `connect` block to select Actions and Triggers from a connector.
  Generated Actions use the binding selected for the current Signal. Use
  `signals` to distinguish bindings that expose the same Action. The host
  supplies the live context for each binding under `:connect`. Set
  `credential_resolver` on the binding or supply it in that live context.
  Hosts can look up a selected Trigger with `trigger/3` before delivery.
  """

  alias Jido.Agent
  alias Jido.Connect
  alias Jido.Connect.{Context, Error, Provider, TriggerSpec}
  alias Jido.Plugin.Context.Admission
  alias Spark.Dsl.Extension

  defmodule Binding do
    @moduledoc false
    defstruct [
      :name,
      :integration,
      :actions,
      :triggers,
      :signals,
      :credential_resolver,
      :__spark_metadata__
    ]
  end

  @binding %Spark.Dsl.Entity{
    name: :binding,
    target: Binding,
    args: [:name, :integration],
    schema: [
      name: [type: :atom, required: true],
      integration: [type: :atom, required: true],
      actions: [type: {:list, :atom}, default: []],
      triggers: [type: {:list, :string}, default: []],
      signals: [type: {:list, :string}, default: []],
      credential_resolver: [type: :atom]
    ]
  }

  @section %Spark.Dsl.Section{name: :connect, entities: [@binding]}
  @binding_keys [:name, :integration, :actions, :triggers, :signals, :credential_resolver]
  @context_keys [
    :integration_context,
    :connection_resolver,
    :credential_resolver,
    :policy,
    :policy_context,
    :provider_client,
    :request_timeout_ms
  ]

  use Jido.Plugin, id: "jido.connect", sections: [@section]

  @impl Jido.Agent.Extension
  def lower(dsl, config) do
    case Extension.get_entities(dsl, [:connect]) do
      [] ->
        {:ok, config}

      bindings when config == %{} ->
        {:ok, %{bindings: Enum.map(bindings, &Map.take(&1, @binding_keys))}}

      _bindings ->
        {:error, :use_connect_block_or_config}
    end
  end

  @impl Jido.Agent.Extension
  def normalize(%{bindings: [_ | _] = bindings} = config) when map_size(config) == 1 do
    with :ok <- validate_bindings(bindings) do
      if Enum.uniq_by(bindings, & &1.name) == bindings,
        do: {:ok, config},
        else: {:error, :duplicate_connect_binding}
    end
  end

  def normalize(_config), do: {:error, :connect_bindings_required}

  @doc "Returns the provider Trigger contract selected on a named Agent binding."
  @spec trigger(Agent.t() | module(), atom(), String.t()) ::
          {:ok, TriggerSpec.t()} | {:error, Error.error()}
  def trigger(agent, name, trigger_id) do
    %{plugins: plugins} = Agent.definition(agent)

    with %{data: %{bindings: bindings}} <- Enum.find(plugins, &(&1.provider == __MODULE__)),
         %{integration: integration, triggers: triggers} <-
           Enum.find(bindings, &(&1.name == name)),
         true <- trigger_id in triggers do
      Connect.trigger(integration, trigger_id)
    else
      _other ->
        {:error,
         Error.config("Connect binding does not select this Trigger",
           key: :connect,
           details: %{binding: name, trigger_id: trigger_id}
         )}
    end
  end

  @impl Jido.Plugin
  def admit(_runtime, %Admission{caller_context: caller, signal: signal}, opts) do
    bindings = Keyword.fetch!(opts, :bindings)

    with contexts when is_map(contexts) <- Map.get(caller, :connect, %{}) do
      contexts =
        for %{name: name} <- bindings,
            context = Map.get(contexts, name),
            is_map(context),
            into: %{} do
          {name, binding_options(context)}
        end

      {:ok, %{bindings: bindings, contexts: contexts, signal_type: signal && signal.type}}
    else
      _other -> {:error, Error.config("Expected Connect contexts by binding name", key: :connect)}
    end
  end

  defp binding_options(%Context{} = context), do: %{integration_context: context}
  defp binding_options(context), do: Map.take(context, @context_keys)

  @doc false
  def action_context(
        %{
          plugin_inputs: %{
            __MODULE__ => %{runtime: %{bindings: bindings, signal_type: signal_type} = runtime}
          }
        },
        action
      ) do
    case Enum.filter(bindings, &matches_action?(&1, action, signal_type)) do
      [binding] -> binding_context(runtime, binding, action)
      matches -> selection_error(action, Enum.map(matches, & &1.name), signal_type)
    end
  end

  def action_context(%{plugin_inputs: %{__MODULE__ => _input}}, action),
    do: selection_error(action, [], nil)

  def action_context(context, _action), do: {:ok, context}

  @doc "Returns the host's live Action context for an Action selected on a named binding."
  @spec action_context(map(), atom(), module()) :: {:ok, map()} | {:error, Error.error()}
  def action_context(context, name, action) do
    runtime = get_in(context, [:plugin_inputs, __MODULE__, Access.key(:runtime)])

    with %{bindings: bindings, signal_type: signal_type} <- runtime,
         %{} = binding <- Enum.find(bindings, &(&1.name == name)),
         true <- matches_action?(binding, action, signal_type) do
      binding_context(runtime, binding, action)
    else
      _other -> binding_error(name, action)
    end
  end

  defp matches_action?(%{actions: actions} = binding, action, signal_type) do
    signals = Map.get(binding, :signals, [])
    action in actions and (signals == [] or signal_type in signals)
  end

  defp binding_context(
         %{contexts: contexts},
         %{name: name, integration: integration} = binding,
         action
       ) do
    with %{integration_context: %Context{} = selected} = context <- Map.get(contexts, name),
         {:ok, %{id: provider}} <- Provider.spec(integration),
         %{provider: ^provider} <- selected.connection || selected.connection_selector do
      case Map.get(binding, :credential_resolver) do
        nil -> {:ok, context}
        resolver -> {:ok, Map.put(context, :credential_resolver, resolver)}
      end
    else
      _other -> binding_error(name, action)
    end
  end

  defp binding_error(name, action) do
    {:error,
     Error.config("Connect Action requires a selected binding with a live context",
       key: :connect,
       details: %{binding: name, action: action}
     )}
  end

  defp selection_error(action, bindings, signal_type) do
    {:error,
     Error.config("Connect Action requires exactly one binding for the current Signal",
       key: :connect,
       details: %{action: action, bindings: bindings, signal_type: signal_type}
     )}
  end

  defp validate_bindings(bindings) when is_list(bindings) do
    Enum.reduce_while(bindings, :ok, fn binding, :ok ->
      case validate_binding(binding) do
        :ok -> {:cont, :ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp validate_binding(
         %{name: name, integration: integration, actions: actions, triggers: triggers} = binding
       )
       when is_atom(name) and not is_nil(name) and is_atom(integration) and
              is_list(actions) and is_list(triggers) do
    with [] <- Map.keys(binding) -- @binding_keys,
         true <- valid_signals?(Map.get(binding, :signals, [])),
         true <- valid_resolver?(Map.get(binding, :credential_resolver)),
         {:module, ^integration} <- Code.ensure_compiled(integration),
         {:ok, manifest} <- Provider.manifest(integration),
         [] <- actions -- Enum.map(manifest.actions, & &1.module),
         [] <- triggers -- Enum.map(manifest.triggers, & &1.id) do
      :ok
    else
      _other -> {:error, {:invalid_connect_selection, name, integration}}
    end
  end

  defp validate_binding(_binding), do: {:error, :invalid_connect_binding}

  defp valid_signals?(signals) do
    is_list(signals) and Enum.all?(signals, &(is_binary(&1) and &1 != ""))
  end

  defp valid_resolver?(nil), do: true

  defp valid_resolver?(module) when is_atom(module) do
    match?({:module, ^module}, Code.ensure_compiled(module)) and
      function_exported?(module, :resolve_lease, 3)
  end

  defp valid_resolver?(_module), do: false
end
