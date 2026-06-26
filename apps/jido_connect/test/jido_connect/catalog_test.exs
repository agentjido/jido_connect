unless Code.ensure_loaded?(Jido.Action.Catalog) do
  defmodule Jido.Action.Catalog do
    defstruct id: nil, name: nil, description: "", entries: %{}, metadata: %{}

    def new(attrs) when is_map(attrs) do
      {:ok,
       %__MODULE__{
         id: Map.fetch!(attrs, :id),
         name: Map.get(attrs, :name),
         description: Map.get(attrs, :description, ""),
         entries: %{},
         metadata: Map.get(attrs, :metadata, %{})
       }}
    end

    def register(%__MODULE__{} = _catalog, nil, _overrides) do
      {:error, :invalid_module}
    end

    def register(%__MODULE__{} = catalog, module, overrides) do
      entry = Map.merge(%{module: module}, overrides)
      {:ok, %{catalog | entries: Map.put(catalog.entries, entry.id, entry)}}
    end
  end
end

defmodule Jido.Connect.CatalogTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Catalog
  alias Jido.Connect.CatalogFixtures
  alias Jido.Connect.Catalog.Actions.{CallTool, DescribeTool, SearchTools}

  defmodule PreferActionRanker do
    def rank(_query, candidates) do
      Process.put(:catalog_ranker_candidates, candidates)

      [
        %{provider: :catalog, id: "catalog.item.get", reason: "prefer action"},
        %{provider: :catalog, id: "missing"},
        "missing.provider.tool"
      ]
    end
  end

  defmodule ExplodingRanker do
    def rank(_query, _candidates), do: raise("ranker exploded")
  end

  defmodule Handler do
    def run(input, _context), do: {:ok, input}
  end

  defmodule GeneratedIntegration do
    use Jido.Connect

    integration do
      id :generated_catalog
      name "Generated Catalog"
      category :test
    end

    catalog do
      package :jido_connect_generated_catalog
      tags [:generated_catalog_test]
      metadata %{version: "1.2.3"}
    end

    auth do
      api_key :user do
        default? true
        owner :app_user
        subject :user
        label "User API key"
        setup :api_key
        credential_fields [:api_key]
        lease_fields [:api_key]
        scopes ["read"]
        default_scopes ["read"]
      end
    end

    actions do
      action :get_item do
        id "generated.item.get"
        resource :item
        verb :get
        data_classification :workspace_metadata
        label "Get generated item"
        description "Fetch an item through a generated action."
        tags [:inventory, :read_model]
        handler Handler
        effect :read

        access do
          auth :user
          scopes ["read"]
        end

        input do
          field :id, :string, required?: true
        end

        output do
          field :id, :string
        end
      end
    end
  end

  test "catalog entries derive host-facing metadata from specs" do
    entry = Catalog.entry(CatalogFixtures.Integration)
    manifest = Catalog.manifest(CatalogFixtures.Integration)

    assert %Catalog.Entry{
             id: :catalog,
             package: :jido_connect_catalog,
             version: "1.2.3",
             tags: [:catalog_test],
             policies: [%{id: :item_access}]
           } = entry

    assert Enum.any?(entry.capabilities, &(&1.feature == :oauth2))
    assert Enum.any?(entry.capabilities, &(&1.feature == :generated_jido_actions))
    assert Enum.any?(entry.capabilities, &(&1.feature == :polling))

    assert [
             %Catalog.AuthProfileSummary{
               id: :user,
               kind: :oauth2,
               credential_fields: [:access_token],
               lease_fields: [:access_token]
             }
           ] = entry.auth_profiles

    assert [
             %Catalog.Tool{
               id: "catalog.item.get",
               type: :action,
               tags: [:inventory, :read_model],
               resource: :item,
               verb: :get
             }
           ] =
             entry.actions

    assert [
             %Catalog.Tool{
               id: "catalog.item.created",
               type: :trigger,
               tags: [:inventory, :events],
               trigger_kind: :poll,
               resource: :item,
               verb: :watch
             }
           ] =
             entry.triggers

    assert [%Catalog.Entry{id: :catalog}] = Catalog.entries([CatalogFixtures.Integration])

    assert %Catalog.Manifest{
             id: :catalog,
             package: :jido_connect_catalog,
             version: "1.2.3",
             generated_modules: %{actions: [], sensors: [], plugin: nil}
           } = manifest
  end

  test "catalog discovery searches and filters configured modules" do
    modules = [CatalogFixtures.Integration]

    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(modules: modules)
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(modules: modules, query: "item")
    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(modules: modules, status: :available)

    assert [%Catalog.Entry{id: :catalog}] =
             Catalog.discover(modules: modules, auth_kind: "oauth2")

    assert [%Catalog.Entry{id: :catalog}] =
             Catalog.discover(modules: modules, auth_profile: "user")

    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(modules: modules, scope: "read")

    assert [%Catalog.Entry{id: :catalog}] =
             Catalog.discover(modules: modules, package: "jido_connect_catalog")

    assert [%Catalog.Entry{id: :catalog}] =
             Catalog.discover(modules: modules, tag: "catalog_test")

    assert [%Catalog.Entry{id: :catalog}] =
             Catalog.discover(modules: modules, capability_kind: "auth")

    assert [%Catalog.Entry{id: :catalog}] =
             Catalog.discover(modules: modules, capability: "polling")

    assert [%Catalog.Entry{id: :catalog}] =
             Catalog.discover(modules: modules, tool: "catalog.item.get")

    assert [] = Catalog.discover(modules: modules, query: "missing")
    assert [] = Catalog.discover(modules: modules, status: "unknown_status")

    assert %{
             id: :catalog,
             module: "Jido.Connect.CatalogFixtures.Integration",
             version: "1.2.3",
             capabilities: [%{provider: :catalog} | _],
             policies: [%{id: :item_access}],
             actions: [%{id: "catalog.item.get", tags: [:inventory, :read_model]}]
           } = Catalog.discover(modules: modules) |> hd() |> Catalog.to_map()

    assert [
             %Catalog.ToolEntry{
               provider: :catalog,
               type: :action,
               id: "catalog.item.get",
               package_version: "1.2.3",
               tags: [:inventory, :read_model],
               auth_kinds: [:oauth2]
             },
             %Catalog.ToolEntry{
               provider: :catalog,
               type: :trigger,
               id: "catalog.item.created"
             }
           ] = Catalog.tools(modules: modules)

    assert [%Catalog.ToolEntry{id: "catalog.item.get"}] =
             Catalog.tools(modules: modules, type: :action)

    assert [%Catalog.ToolEntry{id: "catalog.item.get"}] =
             Catalog.tools(modules: modules, resource: :item, verb: :get)

    assert [%Catalog.ToolEntry{id: "catalog.item.created"}] =
             Catalog.tools(modules: modules, query: "created")

    assert [%Catalog.ToolEntry{id: "catalog.item.get"}] =
             Catalog.tools(modules: modules, tool_tag: :read_model)

    assert [%Catalog.ToolEntry{id: "catalog.item.get"}] =
             Catalog.tools(modules: modules, tool: "catalog.item.get")

    assert [
             %Catalog.ToolEntry{id: "catalog.item.get"},
             %Catalog.ToolEntry{id: "catalog.item.created"}
           ] = Catalog.tools(modules: modules, auth_kind: :oauth2)

    assert %{
             provider: :catalog,
             integration_module: "Jido.Connect.CatalogFixtures.Integration",
             package_version: "1.2.3",
             id: "catalog.item.get",
             tags: [:inventory, :read_model],
             auth_kinds: [:oauth2],
             policies: [:item_access],
             resource: :item,
             verb: :get
           } = Catalog.tools(modules: modules, type: :action) |> hd() |> Catalog.to_map()
  end

  test "catalog discovery includes app-registered provider modules" do
    previous_modules = Application.get_env(:jido_connect, :catalog_modules)
    previous_providers = Application.get_env(:jido_connect, :jido_connect_providers)

    Application.put_env(:jido_connect, :catalog_modules, [])
    Application.put_env(:jido_connect, :jido_connect_providers, [CatalogFixtures.Integration])

    on_exit(fn ->
      restore_env(:catalog_modules, previous_modules)
      restore_env(:jido_connect_providers, previous_providers)
    end)

    assert CatalogFixtures.Integration in Catalog.configured_modules()
    assert CatalogFixtures.Integration in Catalog.registered_modules()
    assert Enum.any?(Catalog.discover(), &(&1.id == :catalog))
  end

  test "catalog discovery skips modules that fail while building entries" do
    modules = [
      CatalogFixtures.Integration,
      CatalogFixtures.RaisingIntegration,
      CatalogFixtures.InvalidIntegration,
      CatalogFixtures.MissingIntegrationCallback,
      Module.concat(__MODULE__, MissingIntegration)
    ]

    assert [%Catalog.Entry{id: :catalog}] = Catalog.discover(modules: modules)

    assert %Catalog.DiscoveryResult{
             entries: [%Catalog.Entry{id: :catalog}],
             diagnostics: diagnostics
           } = Catalog.discover_with_diagnostics(modules: modules)

    assert Enum.map(diagnostics, & &1.reason) == [
             :entry_failed,
             :entry_failed,
             :missing_integration_callback,
             :module_not_loaded
           ]

    assert Enum.any?(diagnostics, &(&1.module == CatalogFixtures.RaisingIntegration))
    assert Enum.any?(diagnostics, &(&1.module == CatalogFixtures.InvalidIntegration))
    assert Enum.any?(diagnostics, &(&1.module == CatalogFixtures.MissingIntegrationCallback))
    assert Enum.any?(diagnostics, &(&1.module == Module.concat(__MODULE__, MissingIntegration)))

    assert [
             %Catalog.ToolEntry{id: "catalog.item.get"},
             %Catalog.ToolEntry{id: "catalog.item.created"}
           ] = Catalog.tools(modules: [CatalogFixtures.Integration])
  end

  test "tool availability evaluates connection scopes without a credential lease" do
    {context, _lease} = CatalogFixtures.context_and_lease()

    assert [
             %{tool: "catalog.item.get", state: :available, connection_id: "conn_catalog"},
             %{tool: "catalog.item.created", state: :available, connection_id: "conn_catalog"}
           ] =
             Catalog.tool_availability(
               modules: [CatalogFixtures.Integration],
               connection: context.connection
             )

    missing_scope_connection = %{context.connection | scopes: []}

    assert [
             %{tool: "catalog.item.get", state: :missing_scopes, missing_scopes: ["read"]},
             %{tool: "catalog.item.created", state: :missing_scopes, missing_scopes: ["read"]}
           ] =
             Catalog.tool_availability(
               modules: [CatalogFixtures.Integration],
               connection: missing_scope_connection
             )
  end

  test "tool availability reports missing connections and allow-list restrictions" do
    assert [
             %{tool: "catalog.item.get", state: :connection_required},
             %{tool: "catalog.item.created", state: :connection_required}
           ] = Catalog.tool_availability(modules: [CatalogFixtures.Integration])

    assert [
             %{tool: "catalog.item.get", state: :disabled_by_policy},
             %{tool: "catalog.item.created", state: :connection_required}
           ] =
             Catalog.tool_availability(
               modules: [CatalogFixtures.Integration],
               allowed_actions: []
             )

    assert [
             %{tool: "catalog.item.get", state: :connection_required},
             %{tool: "catalog.item.created", state: :disabled_by_policy}
           ] =
             Catalog.tool_availability(
               modules: [CatalogFixtures.Integration],
               allowed_triggers: []
             )
  end

  test "tool availability treats disconnected provider connections as unavailable" do
    {context, _lease} = CatalogFixtures.context_and_lease()
    disconnected = %{context.connection | status: :revoked}

    assert [
             %{
               tool: "catalog.item.get",
               state: :connection_required,
               connection_id: "conn_catalog"
             },
             %{
               tool: "catalog.item.created",
               state: :connection_required,
               connection_id: "conn_catalog"
             }
           ] =
             Catalog.tool_availability(
               modules: [CatalogFixtures.Integration],
               connection: disconnected
             )
  end

  test "action catalog bridge projects generated action modules" do
    assert {:ok, catalog} = Catalog.action_catalog(modules: [GeneratedIntegration])
    assert %{entries: %{"generated.item.get" => entry}} = catalog
    assert entry.module == GeneratedIntegration.Actions.GetItem
    assert entry.title == "Get generated item"
    assert entry.namespace == "generated_catalog"
    assert entry.scopes == ["read"]
    assert entry.read_only? == true
    assert entry.metadata.provider == :generated_catalog
    assert "read_model" in entry.tags
    assert entry.metadata.package_version == "1.2.3"
  end

  test "action catalog bridge skips non-generated catalog tools" do
    assert {:ok, catalog} = Catalog.action_catalog(modules: [CatalogFixtures.Integration])
    assert catalog.entries == %{}
  end

  test "ranked tool search prefers exact matches and combines with filters" do
    modules = [CatalogFixtures.Integration, CatalogFixtures.OtherIntegration]

    assert [
             %Catalog.ToolSearchResult{
               tool: %Catalog.ToolEntry{id: "catalog.item.get", type: :action},
               score: score,
               matched_fields: matched_fields
             }
             | _
           ] = Catalog.search_tools("catalog.item.get", modules: modules)

    assert score >= 1_000
    assert :id in matched_fields

    assert [
             %Catalog.ToolSearchResult{
               tool: %Catalog.ToolEntry{id: "catalog.item.get"},
               matched_fields: tag_fields
             }
           ] = Catalog.search_tools("read_model", modules: [CatalogFixtures.Integration])

    assert :tags in tag_fields

    assert [
             %Catalog.ToolSearchResult{tool: %Catalog.ToolEntry{id: "catalog.item.created"}},
             %Catalog.ToolSearchResult{tool: %Catalog.ToolEntry{id: "catalog.item.created"}}
           ] =
             Catalog.search_tools("item", modules: modules, type: :trigger)

    assert [%Catalog.ToolSearchResult{tool: %Catalog.ToolEntry{provider: :other_catalog}}] =
             Catalog.search_tools("item",
               modules: modules,
               provider: :other_catalog,
               type: :action
             )

    assert [%Catalog.ToolSearchResult{tool: %Catalog.ToolEntry{id: "catalog.item.get"}}] =
             Catalog.search_tools("inventory",
               modules: [CatalogFixtures.Integration],
               type: :action,
               tool_tag: :read_model
             )

    assert [] = Catalog.search_tools("missing", modules: modules)
  end

  test "tool lookup resolves ids and provider-qualified references" do
    modules = [CatalogFixtures.Integration, CatalogFixtures.OtherIntegration]

    assert {:error, %Jido.Connect.Error.ValidationError{reason: :ambiguous_tool}} =
             Catalog.lookup_tool("catalog.item.get", modules: modules)

    assert {:ok, %Catalog.ToolEntry{provider: :catalog, id: "catalog.item.get"}} =
             Catalog.lookup_tool({:catalog, "catalog.item.get"}, modules: modules)

    assert {:ok, %Catalog.ToolEntry{provider: :other_catalog, id: "catalog.item.get"}} =
             Catalog.lookup_tool("other_catalog.catalog.item.get", modules: modules)

    assert {:error, %Jido.Connect.Error.ValidationError{reason: :unknown_tool}} =
             Catalog.lookup_tool("missing.tool", modules: modules)

    assert {:error, %Jido.Connect.Error.ValidationError{reason: :invalid_tool_ref}} =
             Catalog.lookup_tool(%{bad: :ref}, modules: modules)
  end

  test "tool descriptors include provider, schema, auth, policy, and source metadata" do
    modules = [CatalogFixtures.Integration]

    assert {:ok,
            %Catalog.ToolDescriptor{
              tool: %Catalog.ToolEntry{
                id: "catalog.item.get",
                tags: [:inventory, :read_model],
                source: :curated
              },
              provider: %{id: :catalog, package: :jido_connect_catalog, version: "1.2.3"},
              input: [%{name: :id}],
              output: [%{name: :id}],
              auth: [%{id: :user, kind: :oauth2, credential_fields: [:access_token]}],
              policies: [%{id: :item_access}],
              scopes: ["read"],
              source: :curated
            } = descriptor} =
             Catalog.describe_tool("catalog.item.get", modules: modules)

    assert %{
             tool: %{id: "catalog.item.get", tags: [:inventory, :read_model], source: :curated},
             provider: %{id: :catalog, version: "1.2.3"},
             input: [%{name: :id}],
             output: [%{name: :id}],
             auth: [
               %{id: :user, credential_fields: [:access_token], lease_fields: [:access_token]}
             ],
             policies: [%{id: :item_access}],
             source: :curated
           } = Catalog.to_map(descriptor)

    assert {:ok,
            %Catalog.ToolDescriptor{
              tool: %Catalog.ToolEntry{id: "catalog.item.created"},
              config: [%{name: :id}],
              signal: [%{name: :id}]
            }} = Catalog.describe_tool("catalog.item.created", modules: modules)
  end

  test "call_tool invokes actions and rejects triggers through the catalog boundary" do
    modules = [CatalogFixtures.Integration]
    {context, lease} = CatalogFixtures.context_and_lease()

    assert {:ok, %{id: "item_1"}} =
             Catalog.call_tool("catalog.item.get", %{id: "item_1"},
               modules: modules,
               context: context,
               credential_lease: lease
             )

    assert {:error, %Jido.Connect.Error.ValidationError{reason: :trigger_not_callable}} =
             Catalog.call_tool("catalog.item.created", %{id: "item_1"},
               modules: modules,
               context: context,
               credential_lease: lease
             )

    assert {:error, %Jido.Connect.Error.ValidationError{reason: :invalid_tool_invocation}} =
             Catalog.call_tool("catalog.item.get", [:bad_input], modules: modules)
  end

  test "catalog packs restrict search, describe, and call" do
    modules = [CatalogFixtures.Integration]

    pack =
      Catalog.Pack.new!(%{
        id: :items,
        filters: %{type: :action},
        allowed_tools: ["catalog.item.get"]
      })

    {context, lease} = CatalogFixtures.context_and_lease()

    assert [%Catalog.ToolSearchResult{tool: %Catalog.ToolEntry{id: "catalog.item.get"}}] =
             Catalog.search_tools("item", modules: modules, pack: pack)

    assert {:ok, %Catalog.ToolDescriptor{tool: %Catalog.ToolEntry{id: "catalog.item.get"}}} =
             Catalog.describe_tool("catalog.item.get",
               modules: modules,
               pack: :items,
               packs: [pack]
             )

    assert {:ok, %{id: "item_1"}} =
             Catalog.call_tool("catalog.item.get", %{id: "item_1"},
               modules: modules,
               pack: :items,
               packs: [pack],
               context: context,
               credential_lease: lease
             )

    assert {:error, %Jido.Connect.Error.ValidationError{reason: :unknown_tool}} =
             Catalog.describe_tool("catalog.item.created", modules: modules, pack: pack)

    allow_list_pack = Catalog.Pack.new!(%{id: :only_get, allowed_tools: ["catalog.item.get"]})

    assert {:error, %Jido.Connect.Error.ValidationError{reason: :tool_not_in_pack}} =
             Catalog.describe_tool("catalog.item.created",
               modules: modules,
               pack: allow_list_pack
             )

    assert {:error, %Jido.Connect.Error.ValidationError{reason: :unknown_pack}} =
             Catalog.describe_tool("catalog.item.get",
               modules: modules,
               pack: :missing,
               packs: [pack]
             )
  end

  test "catalog actions normalize inputs and delegate to core catalog APIs" do
    modules = [CatalogFixtures.Integration]
    {context, lease} = CatalogFixtures.context_and_lease()

    pack =
      Catalog.Pack.new!(%{
        id: "actions",
        filters: %{type: :action},
        allowed_tools: ["catalog.item.get"]
      })

    action_context = %{
      config: %{modules: modules, packs: [pack]},
      context: context,
      credential_lease: lease
    }

    assert {:ok, %{results: [%{tool: %{id: "catalog.item.get"}}]}} =
             SearchTools.run(
               %{
                 "query" => "item",
                 "filters" => %{"type" => "action"},
                 "limit" => "1",
                 "pack" => "actions"
               },
               action_context
             )

    assert {:ok, %{descriptor: %{tool: %{id: "catalog.item.get"}}}} =
             DescribeTool.run(%{"tool_id" => "catalog.item.get"}, action_context)

    assert {:ok, %{result: %{id: "item_1"}}} =
             CallTool.run(
               %{"tool_id" => "catalog.item.get", "input" => %{"id" => "item_1"}},
               action_context
             )

    assert {:error, %Jido.Connect.Error.ValidationError{reason: :trigger_not_callable}} =
             CallTool.run(%{"tool_id" => "catalog.item.created", "input" => %{}}, action_context)

    assert {:error, %Jido.Connect.Error.ValidationError{reason: :invalid_filters}} =
             SearchTools.run(%{"query" => "item", "filters" => "bad"}, action_context)
  end

  test "catalog plugin exposes exactly search, describe, and call actions" do
    spec = Catalog.Plugin.plugin_spec(%{modules: [CatalogFixtures.Integration]})

    assert spec.actions == [SearchTools, DescribeTool, CallTool]

    assert Catalog.Plugin.signal_routes(%{}) == [
             {"connect.catalog.search", SearchTools},
             {"connect.catalog.describe", DescribeTool},
             {"connect.catalog.call", CallTool}
           ]
  end

  test "ranker extension reorders valid candidates and receives sanitized metadata only" do
    modules = [CatalogFixtures.Integration]

    assert [
             %Catalog.ToolSearchResult{
               tool: %Catalog.ToolEntry{id: "catalog.item.get"},
               metadata: %{ranker: %{rank: 1, reason: "prefer action"}}
             },
             %Catalog.ToolSearchResult{tool: %Catalog.ToolEntry{id: "catalog.item.created"}}
           ] = Catalog.search_tools("item", modules: modules, ranker: PreferActionRanker)

    assert [%{"tool" => candidate, "score" => _, "matched_fields" => _} | _] =
             Process.get(:catalog_ranker_candidates)

    assert candidate["id"] in ["catalog.item.get", "catalog.item.created"]
    refute Map.has_key?(candidate, :credentials)
    refute Map.has_key?(candidate, :credential_lease)
    refute Map.has_key?(candidate, "credentials")
    refute Map.has_key?(candidate, "credential_lease")
  end

  test "ranker failures fall back to deterministic results with diagnostic metadata" do
    modules = [CatalogFixtures.Integration]

    assert [
             %Catalog.ToolSearchResult{
               tool: %Catalog.ToolEntry{id: "catalog.item.created"},
               metadata: %{ranker: %{status: :fallback, error: %{type: :execution_error}}}
             },
             %Catalog.ToolSearchResult{
               tool: %Catalog.ToolEntry{id: "catalog.item.get"},
               metadata: %{ranker: %{status: :fallback, error: %{type: :execution_error}}}
             }
           ] = Catalog.search_tools("item", modules: modules, ranker: ExplodingRanker)
  end

  defp restore_env(key, nil), do: Application.delete_env(:jido_connect, key)
  defp restore_env(key, value), do: Application.put_env(:jido_connect, key, value)
end
