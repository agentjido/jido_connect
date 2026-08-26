defmodule Jido.Connect.Catalog do
  @moduledoc """
  Host-facing connector catalog metadata derived from integration specs.

  `Catalog.Item` is the canonical read-only operation projection. This gives
  demo apps and host UIs a stable, storage-free way to render available
  providers, auth modes, generated operations, and maturity metadata.

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
    Item,
    ItemLookup,
    ItemSearchResult,
    Manifest,
    Pack,
    Ranker,
    ReviewedDescriptor,
    Search,
    Serializer,
    ToolEntry,
    ToolDescriptor,
    ToolSearchResult
  }

  alias Jido.Connect.{Authorization, Callback, Connection, Context, Error}
  alias Jido.Connect.Provider
  alias Jido.Connect.Jido.ToolAvailability

  @spec entry(module(), keyword()) :: Entry.t()
  defdelegate entry(integration_module, opts \\ []), to: Builder

  @spec manifest(module(), keyword()) :: Manifest.t()
  defdelegate manifest(integration_module, opts \\ []), to: Builder

  @spec entries([module()], keyword()) :: [Entry.t()]
  def entries(integration_modules, opts \\ []) when is_list(integration_modules) do
    Enum.map(integration_modules, &entry(&1, opts))
  end

  @doc """
  Returns reviewed executable descriptors for exact integration modules and one supplied pack.

  This API never uses configured or installed connector discovery. A reviewed
  pack must name only actions from the supplied modules. Triggers and the
  generic MCP bridge actions are not executable reviewed descriptors.
  """
  @spec reviewed_descriptors(module() | [module()], Pack.t() | map()) ::
          {:ok, [ToolDescriptor.t()]} | {:error, Error.error()}
  def reviewed_descriptors(integration_module, pack) when is_atom(integration_module) do
    reviewed_descriptors([integration_module], pack)
  end

  def reviewed_descriptors(integration_modules, pack) when is_list(integration_modules) do
    case reviewed_items(integration_modules, pack) do
      {:ok, items} -> {:ok, Enum.map(items, &ToolDescriptor.from_item/1)}
      {:error, _error} = error -> error
    end
  end

  def reviewed_descriptors(integration_modules, _pack) do
    invalid_reviewed_modules(integration_modules)
  end

  @doc "Returns canonical reviewed action items for exact modules and one supplied pack."
  @spec reviewed_items(module() | [module()], Pack.t() | map()) ::
          {:ok, [Item.t()]} | {:error, Error.error()}
  def reviewed_items(integration_module, pack) when is_atom(integration_module) do
    reviewed_items([integration_module], pack)
  end

  def reviewed_items(integration_modules, pack) when is_list(integration_modules) do
    with :ok <- require_exact_modules(integration_modules),
         {:ok, pack} <- Pack.resolve_exact(pack),
         {:ok, items} <- exact_items(integration_modules),
         :ok <- Pack.validate_reviewed_items(pack, items),
         {:ok, items} <- select_reviewed_actions(items, pack) do
      {:ok, Enum.map(items, &ReviewedDescriptor.project_item(&1, pack))}
    end
  end

  def reviewed_items(integration_modules, _pack) do
    invalid_reviewed_modules(integration_modules)
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

  @doc "Returns canonical catalog items across discovered providers."
  @spec items(keyword() | map()) :: [Item.t()]
  def items(opts \\ []) do
    opts = normalize_opts(opts)

    case Pack.resolve(Keyword.get(opts, :pack), opts) do
      {:ok, pack} ->
        opts
        |> Pack.apply_filters(pack)
        |> item_entries()
        |> Pack.filter_items(pack)
        |> Search.items(Keyword.get(opts, :query, Keyword.get(opts, :q)))

      {:error, _error} ->
        []
    end
  end

  @doc "Returns legacy tool entries adapted from canonical catalog items."
  @spec tools(keyword()) :: [ToolEntry.t()]
  def tools(opts \\ []) do
    opts
    |> items()
    |> Enum.map(&ToolEntry.from_item/1)
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
    |> items()
    |> Enum.map(fn item ->
      catalog_tool_availability(item, opts, connection, allowed_actions, allowed_triggers)
    end)
  end

  @doc "Returns ranked canonical item search results across discovered providers."
  @spec search_items(String.t() | nil, keyword() | map()) ::
          [ItemSearchResult.t()] | {:error, Error.error()}
  def search_items(query, opts \\ []) do
    opts = normalize_opts(opts)

    with {:ok, pack} <- Pack.resolve(Keyword.get(opts, :pack), opts) do
      opts
      |> Keyword.drop([:query, :q, :ranker])
      |> Pack.apply_filters(pack)
      |> item_entries()
      |> Pack.filter_items(pack)
      |> Search.ranked_items(query)
      |> Ranker.apply(query, Keyword.get(opts, :ranker))
      |> Pack.filter_search_results(pack)
    end
  end

  @doc "Returns legacy ranked tool results adapted from canonical item results."
  @spec search_tools(String.t() | nil, keyword() | map()) ::
          [ToolSearchResult.t()] | {:error, Jido.Connect.Error.error()}
  def search_tools(query, opts \\ []) do
    case search_items(query, opts) do
      results when is_list(results) ->
        Enum.map(results, &ToolSearchResult.from_item_search_result/1)

      {:error, _error} = error ->
        compatibility_tool_error(error)
    end
  end

  @doc "Looks up one canonical item by ref, id, provider tuple, or `%Item{}`."
  @spec lookup_item(term(), keyword() | map()) :: {:ok, Item.t()} | {:error, Error.error()}
  def lookup_item(item_ref, opts \\ []) do
    opts = normalize_opts(opts)

    with {:ok, pack} <- Pack.resolve(Keyword.get(opts, :pack), opts),
         {:ok, item} <-
           opts
           |> Keyword.drop([:query, :q, :ranker])
           |> Pack.apply_filters(pack)
           |> item_entries()
           |> ItemLookup.lookup(item_ref),
         :ok <- Pack.require_item_allowed(pack, item) do
      {:ok, item}
    end
  end

  @doc "Looks up one legacy tool entry through the canonical item catalog."
  @spec lookup_tool(term(), keyword() | map()) ::
          {:ok, ToolEntry.t()} | {:error, Jido.Connect.Error.error()}
  def lookup_tool(tool_ref, opts \\ []) do
    case lookup_item(compatibility_item_ref(tool_ref), opts) do
      {:ok, item} -> {:ok, ToolEntry.from_item(item)}
      {:error, _error} = error -> compatibility_tool_error(error)
    end
  end

  @doc "Returns the schema-rich canonical item for one operation."
  @spec describe_item(term(), keyword() | map()) :: {:ok, Item.t()} | {:error, Error.error()}
  def describe_item(item_ref, opts \\ []), do: lookup_item(item_ref, opts)

  @doc "Returns a legacy tool descriptor adapted from a canonical item."
  @spec describe_tool(term(), keyword() | map()) ::
          {:ok, ToolDescriptor.t()} | {:error, Jido.Connect.Error.error()}
  def describe_tool(tool_ref, opts \\ []) do
    case describe_item(tool_ref, opts) do
      {:ok, item} -> {:ok, ToolDescriptor.from_item(item)}
      {:error, _error} = error -> compatibility_tool_error(error)
    end
  end

  @doc "Invokes a canonical action item through the core runtime boundary."
  @spec call_item(term(), map(), keyword() | map()) ::
          {:ok, map()} | {:error, Error.error()}
  def call_item(item_ref, input, opts \\ [])

  def call_item(item_ref, input, opts) when is_map(input) do
    with {:ok, item} <- lookup_item(item_ref, call_lookup_opts(opts)),
         :ok <- require_callable(item, :item) do
      Jido.Connect.invoke(item.integration_module, item.id, input, opts)
    end
  end

  def call_item(item_ref, input, _opts) do
    {:error,
     Error.validation("Invalid catalog item invocation",
       reason: :invalid_item_invocation,
       subject: item_ref,
       details: %{input_type: type_name(input)}
     )}
  end

  @doc "Invokes a legacy tool through the canonical item catalog."
  @spec call_tool(term(), map(), keyword() | map()) ::
          {:ok, map()} | {:error, Jido.Connect.Error.error()}
  def call_tool(tool_ref, input, opts \\ [])

  def call_tool(tool_ref, input, opts) when is_map(input) do
    case call_item(tool_ref, input, opts) do
      {:error, _error} = error -> compatibility_tool_error(error)
      result -> result
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
          | Item.t()
          | ItemSearchResult.t()
          | Manifest.t()
          | Pack.t()
          | ToolEntry.t()
          | ToolSearchResult.t()
          | ToolDescriptor.t()
        ) ::
          map()
  defdelegate to_map(entry_or_tool), to: Serializer

  defp item_entries(opts) do
    provider_opts = Keyword.drop(opts, [:query, :q, :type, :risk, :confirmation, :pack, :packs])

    provider_opts
    |> discover()
    |> Enum.flat_map(&items_for_entry/1)
    |> Filter.items(opts)
  end

  defp items_for_entry(%Entry{} = entry) do
    with {:ok, spec} <- Provider.spec(entry.module),
         {:ok, items} <-
           Callback.run(
             fn ->
               Builder.items_from_spec(spec, entry.module, projection(entry.module),
                 status: entry.status,
                 version: entry.version
               )
             end,
             phase: :catalog_item_projection,
             details: %{module: entry.module}
           ) do
      items
    else
      _error -> []
    end
  end

  defp require_exact_modules([]) do
    {:error,
     Error.validation("Reviewed catalog requires at least one integration module",
       reason: :missing_reviewed_modules
     )}
  end

  defp require_exact_modules(integration_modules) do
    if Enum.all?(integration_modules, &is_atom/1) do
      :ok
    else
      {:error,
       Error.validation("Reviewed catalog modules must be integration modules",
         reason: :invalid_reviewed_modules,
         subject: integration_modules
       )}
    end
  end

  defp exact_items(integration_modules) do
    integration_modules
    |> Enum.uniq()
    |> Enum.reduce_while({:ok, []}, fn integration_module, {:ok, items} ->
      with {:ok, spec} <- Provider.spec(integration_module),
           {:ok, projected} <-
             Callback.run(
               fn ->
                 Builder.items_from_spec(spec, integration_module, projection(integration_module))
               end,
               phase: :reviewed_catalog_item_projection,
               details: %{module: integration_module}
             ) do
        {:cont, {:ok, items ++ projected}}
      else
        {:error, _error} = error -> {:halt, error}
      end
    end)
  end

  defp select_reviewed_actions(items, pack) do
    selected = Pack.filter_items(items, pack)

    with :ok <- reject_selected_triggers(selected, pack),
         :ok <- reject_generic_mcp_actions(selected, pack) do
      {:ok, Enum.filter(selected, &(&1.type == :action))}
    end
  end

  defp reject_selected_triggers(tools, pack) do
    case Enum.find(tools, &(&1.type == :trigger)) do
      nil ->
        :ok

      trigger ->
        {:error,
         Error.validation("Reviewed catalog packs cannot project triggers as executable actions",
           reason: :trigger_not_executable,
           subject: trigger.id,
           details: %{provider: trigger.provider, pack: pack.id}
         )}
    end
  end

  defp reject_generic_mcp_actions(tools, pack) do
    case Enum.find(tools, &generic_mcp_bridge_action?/1) do
      nil ->
        :ok

      tool ->
        {:error,
         Error.validation("Generic MCP bridge actions cannot enter a reviewed catalog",
           reason: :generic_mcp_action_not_reviewable,
           subject: tool.id,
           details: %{provider: tool.provider, pack: pack.id}
         )}
    end
  end

  defp generic_mcp_bridge_action?(%Item{id: id}) do
    id in ["mcp.tools.list", "mcp.tools.call", "mcp.tool.call"]
  end

  defp require_callable(%Item{type: :action}, :item), do: :ok

  defp require_callable(%Item{} = item, :item) do
    {:error,
     Error.validation("Catalog item is not callable through call_item/4",
       reason: :trigger_not_callable,
       subject: item.ref,
       details: %{provider: item.provider, type: item.type, id: item.id}
     )}
  end

  defp call_lookup_opts(opts) when is_list(opts), do: opts
  defp call_lookup_opts(opts) when is_map(opts), do: Map.to_list(opts)
  defp call_lookup_opts(_opts), do: []

  defp catalog_tool_availability(
         %Item{} = tool,
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

  defp operation_for_tool(%Item{
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

  defp operation_for_tool(%Item{
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

  defp input_for_tool(%Item{} = tool, opts) do
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
         %Item{type: :action, id: id},
         allowed_actions,
         _allowed_triggers
       ),
       do: allowed_actions && not MapSet.member?(allowed_actions, id)

  defp disabled_by_allowed_set?(
         %Item{type: :trigger, id: id},
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

  defp invalid_reviewed_modules(integration_modules) do
    {:error,
     Error.validation("Reviewed catalog requires a list of exact integration modules",
       reason: :invalid_reviewed_modules,
       subject: integration_modules
     )}
  end

  defp projection(integration_module) do
    if function_exported?(integration_module, :jido_projection, 0) do
      integration_module.jido_projection()
    end
  end

  defp compatibility_item_ref(%ToolEntry{} = tool),
    do: {tool.provider, tool.type, tool.id}

  defp compatibility_item_ref(tool_ref), do: tool_ref

  defp compatibility_tool_error({:error, %Error.ValidationError{} = error}) do
    reason =
      case error.reason do
        :invalid_item_ref -> :invalid_tool_ref
        :unknown_item -> :unknown_tool
        :ambiguous_item -> :ambiguous_tool
        :item_not_in_pack -> :tool_not_in_pack
        :invalid_item_invocation -> :invalid_tool_invocation
        reason -> reason
      end

    message =
      case reason do
        :invalid_tool_ref -> "Invalid catalog tool reference"
        :unknown_tool -> "Unknown catalog tool"
        :ambiguous_tool -> "Catalog tool reference is ambiguous"
        :tool_not_in_pack -> "Catalog tool is not allowed by pack"
        :invalid_tool_invocation -> "Invalid catalog tool invocation"
        _other -> error.message
      end

    {:error, %{error | reason: reason, message: message}}
  end

  defp compatibility_tool_error(error), do: error

  defp normalize_opts(opts) when is_list(opts), do: opts
  defp normalize_opts(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalize_opts(_opts), do: []

  defp maybe_get(map, key), do: Map.get(map, key)

  defp type_name(value) when is_list(value), do: :list
  defp type_name(value) when is_binary(value), do: :string
  defp type_name(value) when is_atom(value), do: :atom
  defp type_name(value) when is_integer(value), do: :integer
  defp type_name(value) when is_float(value), do: :float
  defp type_name(_value), do: :unknown
end
