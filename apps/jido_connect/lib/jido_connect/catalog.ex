defmodule Jido.Connect.Catalog do
  @moduledoc """
  Host-facing connector catalog metadata derived from integration specs.

  This gives demo apps and host UIs a stable, storage-free way to render
  available providers, auth modes, generated tools, and maturity metadata.

  Provider packages self-register their provider module with application env
  `:jido_connect_providers`. Host apps can install only the provider packages
  they want, and discovery will see only loaded provider applications plus any
  modules configured with `config :jido_connect, :catalog_modules, [...]`.

  Use `discover/1` for lenient runtime catalog views and
  `discover_with_diagnostics/1` for CI, demos, and admin screens that should
  report broken or missing connectors.
  """

  alias Jido.Connect.Catalog.{
    Builder,
    Discovery,
    DiscoveryResult,
    Entry,
    Filter,
    Manifest,
    Pack,
    Ranker,
    Search,
    Serializer,
    ToolDescriber,
    ToolEntry,
    ToolLookup,
    ToolDescriptor,
    ToolSearchResult
  }

  alias Jido.Connect.{Authorization, Connection, Context, Error}
  alias Jido.Connect.Jido.ToolAvailability

  @spec entry(module(), keyword()) :: Entry.t()
  defdelegate entry(integration_module, opts \\ []), to: Builder

  @spec manifest(module(), keyword()) :: Manifest.t()
  defdelegate manifest(integration_module, opts \\ []), to: Builder

  @spec entries([module()], keyword()) :: [Entry.t()]
  def entries(integration_modules, opts \\ []) when is_list(integration_modules) do
    Enum.map(integration_modules, &entry(&1, opts))
  end

  @spec configured_modules() :: [module()]
  defdelegate configured_modules, to: Discovery

  @spec registered_modules() :: [module()]
  defdelegate registered_modules, to: Discovery

  @spec discover(keyword()) :: [Entry.t()]
  defdelegate discover(opts \\ []), to: Discovery

  @spec discover_with_diagnostics(keyword()) :: DiscoveryResult.t()
  defdelegate discover_with_diagnostics(opts \\ []), to: Discovery

  @spec search([Entry.t()], String.t() | nil) :: [Entry.t()]
  defdelegate search(entries, query), to: Search, as: :entries

  @spec filter([Entry.t()], keyword()) :: [Entry.t()]
  defdelegate filter(entries, opts), to: Filter, as: :entries

  @doc "Returns a flattened catalog of actions and triggers across discovered providers."
  @spec tools(keyword()) :: [ToolEntry.t()]
  def tools(opts \\ []) do
    opts = normalize_opts(opts)

    case Pack.resolve(Keyword.get(opts, :pack), opts) do
      {:ok, pack} ->
        opts
        |> Pack.apply_filters(pack)
        |> tool_entries()
        |> Pack.filter_tools(pack)
        |> Search.tools(Keyword.get(opts, :query, Keyword.get(opts, :q)))

      {:error, _error} ->
        []
    end
  end

  @doc """
  Returns connection-aware availability for catalog tools.

  This is the plain `Jido.Connect` counterpart to generated plugin
  `tool_availability/1`: host UIs can render actions and triggers before they
  have a credential lease, while still seeing missing scopes and policy blocks.
  """
  @spec tool_availability(keyword() | map()) :: [ToolAvailability.t()]
  def tool_availability(opts \\ []) do
    opts = normalize_opts(opts)
    allowed_actions = allowed_set(opts, :allowed_actions)
    allowed_triggers = allowed_set(opts, :allowed_triggers)
    connection = connection_from_opts(opts)

    opts
    |> tools()
    |> Enum.map(fn tool ->
      catalog_tool_availability(tool, opts, connection, allowed_actions, allowed_triggers)
    end)
  end

  @doc """
  Projects generated connector action modules into `Jido.Action.Catalog`.

  `Jido.Action.Catalog` landed after the currently published `jido_action`
  2.2.1. Until a Hex release includes it, this returns a config error instead
  of requiring a git dependency.
  """
  @spec action_catalog(keyword() | map()) :: {:ok, struct()} | {:error, Error.error()}
  def action_catalog(opts \\ []) do
    opts = normalize_opts(opts)
    catalog_module = Jido.Action.Catalog

    case Code.ensure_loaded(catalog_module) do
      {:module, module} ->
        build_action_catalog(module, opts)

      {:error, reason} ->
        {:error,
         Error.config("Jido.Action.Catalog is not available",
           key: :jido_action_catalog,
           details: %{dependency: :jido_action, reason: reason}
         )}
    end
  end

  @doc "Returns ranked tool search results across discovered providers."
  @spec search_tools(String.t() | nil, keyword() | map()) ::
          [ToolSearchResult.t()] | {:error, Jido.Connect.Error.error()}
  def search_tools(query, opts \\ []) do
    opts = normalize_opts(opts)

    with {:ok, pack} <- Pack.resolve(Keyword.get(opts, :pack), opts) do
      opts
      |> Keyword.drop([:query, :q, :ranker])
      |> Pack.apply_filters(pack)
      |> tool_entries()
      |> Pack.filter_tools(pack)
      |> Search.ranked_tools(query)
      |> Ranker.apply(query, Keyword.get(opts, :ranker))
      |> Pack.filter_search_results(pack)
    end
  end

  @doc "Looks up one catalog tool by id, `{provider, id}`, or `%ToolEntry{}`."
  @spec lookup_tool(term(), keyword() | map()) ::
          {:ok, ToolEntry.t()} | {:error, Jido.Connect.Error.error()}
  def lookup_tool(tool_ref, opts \\ []) do
    opts = normalize_opts(opts)

    with {:ok, pack} <- Pack.resolve(Keyword.get(opts, :pack), opts),
         {:ok, tool} <-
           opts
           |> Keyword.drop([:query, :q, :ranker])
           |> Pack.apply_filters(pack)
           |> tool_entries()
           |> ToolLookup.lookup(tool_ref),
         :ok <- Pack.require_tool_allowed(pack, tool) do
      {:ok, tool}
    end
  end

  @doc "Returns a schema-rich description for one catalog tool."
  @spec describe_tool(term(), keyword() | map()) ::
          {:ok, ToolDescriptor.t()} | {:error, Jido.Connect.Error.error()}
  def describe_tool(tool_ref, opts \\ []) do
    with {:ok, tool} <- lookup_tool(tool_ref, opts) do
      ToolDescriber.describe(tool)
    end
  end

  @doc "Invokes an action catalog tool through the core runtime boundary."
  @spec call_tool(term(), map(), keyword() | map()) ::
          {:ok, map()} | {:error, Jido.Connect.Error.error()}
  def call_tool(tool_ref, input, opts \\ [])

  def call_tool(tool_ref, input, opts) when is_map(input) do
    with {:ok, tool} <- lookup_tool(tool_ref, call_lookup_opts(opts)),
         :ok <- require_callable(tool) do
      Jido.Connect.invoke(tool.integration_module, tool.id, input, opts)
    end
  end

  def call_tool(tool_ref, input, _opts) do
    {:error,
     Jido.Connect.Error.validation("Invalid catalog tool invocation",
       reason: :invalid_tool_invocation,
       subject: tool_ref,
       details: %{input_type: type_name(input)}
     )}
  end

  @spec to_map(
          Entry.t()
          | Manifest.t()
          | Pack.t()
          | ToolEntry.t()
          | ToolSearchResult.t()
          | ToolDescriptor.t()
        ) ::
          map()
  defdelegate to_map(entry_or_tool), to: Serializer

  defp tool_entries(opts) do
    provider_opts = Keyword.drop(opts, [:query, :q, :type, :risk, :confirmation, :pack, :packs])

    provider_opts
    |> discover()
    |> Enum.flat_map(&Builder.tool_entries/1)
    |> Filter.tool_entries(opts)
  end

  defp require_callable(%ToolEntry{type: :action}), do: :ok

  defp require_callable(%ToolEntry{} = tool) do
    {:error,
     Jido.Connect.Error.validation("Catalog tool is not callable through call_tool/4",
       reason: :trigger_not_callable,
       subject: tool.id,
       details: %{provider: tool.provider, type: tool.type}
     )}
  end

  defp call_lookup_opts(opts) when is_list(opts), do: opts
  defp call_lookup_opts(opts) when is_map(opts), do: Map.to_list(opts)
  defp call_lookup_opts(_opts), do: []

  defp catalog_tool_availability(
         %ToolEntry{} = tool,
         opts,
         connection,
         allowed_actions,
         allowed_triggers
       ) do
    cond do
      disabled_by_allowed_set?(tool, allowed_actions, allowed_triggers) ->
        ToolAvailability.new!(%{tool: tool.id, state: :disabled_by_policy})

      match?(%Connection{}, connection) ->
        with {:ok, operation} <- operation_for_tool(tool) do
          operation_connection_availability(
            tool,
            operation,
            connection,
            input_for_tool(tool, opts),
            opts
          )
        else
          {:error, %_{} = error} -> configuration_unavailable(tool, error)
        end

      true ->
        ToolAvailability.new!(%{tool: tool.id, state: :connection_required})
    end
  end

  defp operation_connection_availability(tool, operation, connection, input, opts) do
    case Authorization.connection_availability(operation, connection, input,
           context: Keyword.get(opts, :context),
           policy: Keyword.get(opts, :policy),
           policy_context: Keyword.get(opts, :policy_context, %{})
         ) do
      {:available, _required_scopes} ->
        ToolAvailability.new!(%{tool: tool.id, state: :available, connection_id: connection.id})

      {:missing_scopes, missing_scopes} ->
        ToolAvailability.new!(%{
          tool: tool.id,
          state: :missing_scopes,
          connection_id: connection.id,
          missing_scopes: missing_scopes
        })

      :disabled_by_policy ->
        ToolAvailability.new!(%{
          tool: tool.id,
          state: :disabled_by_policy,
          connection_id: connection.id
        })

      :connection_required ->
        ToolAvailability.new!(%{
          tool: tool.id,
          state: :connection_required,
          connection_id: connection.id
        })

      {:configuration_error, error} ->
        configuration_unavailable(tool, error, connection.id)
    end
  end

  defp operation_for_tool(%ToolEntry{
         integration_module: integration_module,
         type: :action,
         id: id
       }) do
    integration_module
    |> Jido.Connect.actions()
    |> case do
      {:ok, actions} ->
        case Enum.find(actions, &(&1.id == id)) do
          nil -> {:error, Error.unknown_action(id)}
          action -> {:ok, action}
        end

      {:error, _error} = error ->
        error
    end
  end

  defp operation_for_tool(%ToolEntry{
         integration_module: integration_module,
         type: :trigger,
         id: id
       }) do
    integration_module
    |> Jido.Connect.triggers()
    |> case do
      {:ok, triggers} ->
        case Enum.find(triggers, &(&1.id == id)) do
          nil -> {:error, Error.unknown_trigger(id)}
          trigger -> {:ok, trigger}
        end

      {:error, _error} = error ->
        error
    end
  end

  defp configuration_unavailable(tool, error, connection_id \\ nil) do
    %{
      tool: tool.id,
      state: :configuration_error,
      connection_id: connection_id,
      metadata: %{error: Error.to_map(error)}
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
    |> ToolAvailability.new!()
  end

  defp input_for_tool(%ToolEntry{} = tool, opts) do
    inputs = Keyword.get(opts, :inputs, %{})

    Map.get(inputs, tool.id) ||
      maybe_get(inputs, tool.name) ||
      Keyword.get(opts, :input, %{})
  end

  defp connection_from_opts(opts) do
    Keyword.get(opts, :connection) || context_connection(Keyword.get(opts, :context))
  end

  defp context_connection(%Context{connection: connection}), do: connection
  defp context_connection(%{connection: connection}), do: connection
  defp context_connection(_context), do: nil

  defp disabled_by_allowed_set?(
         %ToolEntry{type: :action, id: id},
         allowed_actions,
         _allowed_triggers
       ),
       do: allowed_actions && not MapSet.member?(allowed_actions, id)

  defp disabled_by_allowed_set?(
         %ToolEntry{type: :trigger, id: id},
         _allowed_actions,
         allowed_triggers
       ),
       do: allowed_triggers && not MapSet.member?(allowed_triggers, id)

  defp allowed_set(opts, key) do
    case Keyword.get(opts, key) do
      nil -> nil
      values when is_list(values) -> MapSet.new(values)
      value -> MapSet.new([value])
    end
  end

  defp build_action_catalog(catalog_module, opts) do
    attrs = %{
      id: Keyword.get(opts, :id, "jido-connect-actions"),
      name: Keyword.get(opts, :name, "Jido Connect Actions"),
      description:
        Keyword.get(
          opts,
          :description,
          "Generated Jido actions exposed by installed Jido Connect providers."
        ),
      metadata: Keyword.get(opts, :metadata, %{})
    }

    with {:ok, catalog} <- apply(catalog_module, :new, [attrs]) do
      opts
      |> Keyword.put(:type, :action)
      |> tools()
      |> Enum.filter(&is_atom(&1.module))
      |> Enum.reduce_while({:ok, catalog}, fn tool, {:ok, acc} ->
        case apply(catalog_module, :register, [acc, tool.module, action_catalog_overrides(tool)]) do
          {:ok, updated} -> {:cont, {:ok, updated}}
          {:error, _error} = error -> {:halt, error}
        end
      end)
    end
  end

  defp action_catalog_overrides(%ToolEntry{} = tool) do
    %{
      id: tool.id,
      title: tool.label,
      description: tool.description || tool.label,
      summary: tool.description || tool.label,
      namespace: to_string(tool.provider),
      package: maybe_to_string(tool.package),
      category: maybe_to_string(tool.category),
      tags: action_catalog_tags(tool),
      capabilities: action_catalog_capabilities(tool),
      visibility: :public,
      risk: action_catalog_risk(tool.risk),
      read_only?: tool.risk in [:read, :metadata],
      requires_confirmation?: tool.confirmation not in [nil, :none],
      scopes: tool.scopes,
      metadata: %{
        provider: tool.provider,
        provider_name: tool.provider_name,
        integration_module: inspect(tool.integration_module),
        resource: tool.resource,
        verb: tool.verb,
        data_classification: tool.data_classification,
        auth_profile: tool.auth_profile,
        auth_profiles: tool.auth_profiles,
        auth_kinds: tool.auth_kinds,
        policies: tool.policies,
        jido_connect_risk: tool.risk,
        confirmation: tool.confirmation
      }
    }
  end

  defp action_catalog_tags(%ToolEntry{} = tool) do
    [tool.provider, tool.category, tool.resource, tool.verb]
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&to_string/1)
  end

  defp action_catalog_capabilities(%ToolEntry{} = tool) do
    [tool.resource, tool.verb, tool.data_classification]
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&to_string/1)
  end

  defp action_catalog_risk(risk) when risk in [:read, :metadata], do: :low
  defp action_catalog_risk(risk) when risk in [:write, :external_write], do: :medium
  defp action_catalog_risk(:destructive), do: :high
  defp action_catalog_risk(_risk), do: :medium

  defp maybe_to_string(nil), do: nil
  defp maybe_to_string(value), do: to_string(value)

  defp normalize_opts(opts) when is_list(opts), do: opts
  defp normalize_opts(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalize_opts(_opts), do: []

  defp maybe_get(map, key) when is_map(map), do: Map.get(map, key)
  defp maybe_get(_map, _key), do: nil

  defp type_name(value) when is_map(value), do: :map
  defp type_name(value) when is_list(value), do: :list
  defp type_name(value) when is_binary(value), do: :string
  defp type_name(value) when is_atom(value), do: :atom
  defp type_name(value) when is_integer(value), do: :integer
  defp type_name(value) when is_float(value), do: :float
  defp type_name(_value), do: :unknown
end
