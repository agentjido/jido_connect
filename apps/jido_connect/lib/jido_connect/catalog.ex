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

  defp normalize_opts(opts) when is_list(opts), do: opts
  defp normalize_opts(opts) when is_map(opts), do: Map.to_list(opts)
  defp normalize_opts(_opts), do: []

  defp type_name(value) when is_list(value), do: :list
  defp type_name(value) when is_binary(value), do: :string
  defp type_name(value) when is_atom(value), do: :atom
  defp type_name(value) when is_integer(value), do: :integer
  defp type_name(value) when is_float(value), do: :float
  defp type_name(_value), do: :unknown
end
