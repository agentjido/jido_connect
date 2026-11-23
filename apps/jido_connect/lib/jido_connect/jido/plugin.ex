defmodule Jido.Connect.Plugin do
  @moduledoc """
  Declares named connector bindings on a Jido v3 Agent.

  Use a `connect` block to select Actions and Triggers from a connector.
  Agent routes define what to do with the resulting Signals. The host starts
  subscriptions and supplies an Action context for each binding in the live
  request's `:connect` context. Supply connection and credential resolvers
  from the host so every operation checks current access.
  """

  alias Jido.Connect.{Context, Error, Provider}
  alias Jido.Plugin.Context.Admission
  alias Spark.Dsl.Extension

  defmodule Binding do
    @moduledoc false
    defstruct [:name, :integration, :actions, :triggers, :__spark_metadata__]
  end

  @binding %Spark.Dsl.Entity{
    name: :binding,
    target: Binding,
    args: [:name, :integration],
    schema: [
      name: [type: :atom, required: true],
      integration: [type: :atom, required: true],
      actions: [type: {:list, :atom}, default: []],
      triggers: [type: {:list, :string}, default: []]
    ]
  }

  @section %Spark.Dsl.Section{name: :connect, entities: [@binding]}
  @binding_keys [:name, :integration, :actions, :triggers]
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

  @impl Jido.Plugin
  def admit(_runtime, %Admission{caller_context: caller}, opts) do
    bindings = Keyword.fetch!(opts, :bindings)

    with contexts when is_map(contexts) <- Map.get(caller, :connect, %{}) do
      contexts =
        for %{name: name} <- bindings,
            context = Map.get(contexts, name),
            is_map(context),
            into: %{} do
          {name, Map.take(context, @context_keys)}
        end

      {:ok, %{bindings: bindings, contexts: contexts}}
    else
      _other -> {:error, Error.config("Expected Connect contexts by binding name", key: :connect)}
    end
  end

  @doc "Returns the host's live Action context for an Action selected on a named binding."
  @spec action_context(map(), atom(), module()) :: {:ok, map()} | {:error, Error.error()}
  def action_context(context, name, action) do
    runtime = get_in(context, [:plugin_inputs, __MODULE__, Access.key(:runtime)])

    with %{bindings: bindings, contexts: contexts} <- runtime,
         %{integration: integration, actions: actions} <- Enum.find(bindings, &(&1.name == name)),
         true <- action in actions,
         %{integration_context: %Context{} = selected} = action_context <- Map.get(contexts, name),
         {:ok, %{id: provider}} <- Provider.spec(integration),
         %{provider: ^provider} <- selected.connection || selected.connection_selector do
      {:ok, action_context}
    else
      _other ->
        {:error,
         Error.config("Connect Action requires a selected binding with a live context",
           key: :connect,
           details: %{binding: name, action: action}
         )}
    end
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
       when map_size(binding) == 4 and is_atom(name) and not is_nil(name) and is_atom(integration) and
              is_list(actions) and is_list(triggers) do
    with {:module, ^integration} <- Code.ensure_compiled(integration),
         {:ok, manifest} <- Provider.manifest(integration),
         [] <- actions -- Enum.map(manifest.actions, & &1.module),
         [] <- triggers -- Enum.map(manifest.triggers, & &1.id) do
      :ok
    else
      _other -> {:error, {:invalid_connect_selection, name, integration}}
    end
  end

  defp validate_binding(_binding), do: {:error, :invalid_connect_binding}
end
