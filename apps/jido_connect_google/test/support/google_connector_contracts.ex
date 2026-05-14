defmodule Jido.Connect.Google.TestSupport.ConnectorContracts do
  @moduledoc false

  import ExUnit.Assertions

  alias Jido.Connect.Taxonomy

  @google_fixture_roots %{
    gmail: "../../fixtures/gmail",
    google_calendar: "../../../fixtures/google_calendar",
    google_drive: "../../../fixtures/google_drive",
    google_sheets: "../../../fixtures/google_sheets"
  }

  @doc "Asserts the generated Jido action, sensor, manifest, and plugin surface."
  def assert_generated_surface(provider, opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)
    action_modules = Keyword.fetch!(opts, :action_modules)
    sensor_specs = Keyword.get(opts, :sensor_specs, [])
    sensor_modules = Enum.map(sensor_specs, &Map.fetch!(&1, :module))
    plugin_module = Keyword.fetch!(opts, :plugin_module)
    plugin_name = Keyword.fetch!(opts, :plugin_name)

    assert Application.get_env(otp_app, :jido_connect_providers) == [provider]
    assert provider.jido_action_modules() == action_modules
    assert provider.jido_sensor_modules() == sensor_modules
    assert provider.jido_plugin_module() == plugin_module

    integration = provider.integration()
    action_ids = integration.actions |> Enum.map(& &1.id) |> MapSet.new()
    integration_id = integration.id
    integration_package = integration.package

    assert %Jido.Connect.Catalog.Manifest{
             id: ^integration_id,
             package: ^integration_package,
             generated_modules: %{
               actions: ^action_modules,
               sensors: ^sensor_modules,
               plugin: ^plugin_module
             }
           } = provider.jido_connect_manifest()

    for module <- action_modules do
      assert {:module, ^module} = Code.ensure_loaded(module)
      assert function_exported?(module, :run, 2)

      projection = module.jido_connect_projection()
      tool = module.to_tool()

      assert projection.module == module
      assert projection.action_id in action_ids
      assert module.operation_id() == projection.action_id
      assert module.name() == projection.name
      assert tool.name == projection.name
    end

    for %{module: module, name: name, trigger_id: trigger_id, signal_type: signal_type} <-
          sensor_specs do
      assert {:module, ^module} = Code.ensure_loaded(module)
      assert function_exported?(module, :handle_event, 2)
      assert module.name() == name
      assert module.trigger_id() == trigger_id
      assert module.signal_type() == signal_type
    end

    assert %Jido.Plugin.Spec{
             name: ^plugin_name,
             module: ^plugin_module,
             actions: ^action_modules
           } = plugin_module.plugin_spec()
  end

  @doc "Asserts generated plugin tool availability for all provider actions and triggers."
  def assert_plugin_tool_availability(provider) do
    spec = provider.integration()
    plugin_module = provider.jido_plugin_module()
    tool_ids = Enum.map(spec.actions ++ spec.triggers, & &1.id)

    assert_availability_ids(plugin_module.tool_availability(), tool_ids)

    for availability <- plugin_module.tool_availability() do
      assert availability.state == :connection_required
    end

    assert_action_allow_list_availability(plugin_module, spec)
    assert_trigger_allow_list_availability(plugin_module, spec)
    assert_connected_availability(plugin_module, spec)
  end

  @doc "Asserts product pack delegate functions and catalog ordering."
  def assert_catalog_pack_delegates(provider, expected_delegates) do
    expected_ids =
      for {function, expected_id} <- expected_delegates do
        assert %{id: ^expected_id} = apply(provider, function, [])
        expected_id
      end

    assert Enum.map(provider.catalog_packs(), & &1.id) == expected_ids
  end

  @doc "Asserts naming, generated module, catalog, classification, and risk conventions."
  def assert_google_naming_and_catalog_conventions(provider, opts) do
    id_prefix = Keyword.fetch!(opts, :id_prefix)
    pack_id_prefix = Keyword.fetch!(opts, :pack_id_prefix)
    module_namespace = Keyword.fetch!(opts, :module_namespace)

    spec = provider.integration()
    action_ids = Enum.map(spec.actions, & &1.id)
    trigger_ids = Enum.map(spec.triggers, & &1.id)
    tool_ids = MapSet.new(action_ids ++ trigger_ids)

    assert :google in spec.tags
    assert :workspace in spec.tags

    for action <- spec.actions do
      assert_google_tool_id(action.id, id_prefix)
      assert_present(action.label)
      assert_known_data_classification(action.data_classification)
      assert_known_risk(action.risk)
      assert_known_confirmation(action.confirmation)
      assert action.scope_resolver

      if action.mutation? do
        assert action.risk in [:write, :external_write, :destructive]
      else
        assert action.risk in [:metadata, :read]
      end

      if action.risk == :external_write do
        refute action.confirmation == :none
      end

      if action.risk == :destructive do
        assert action.confirmation == :always
      end
    end

    for trigger <- spec.triggers do
      assert_google_tool_id(trigger.id, id_prefix)
      assert_present(trigger.label)
      assert_known_data_classification(trigger.data_classification)
      assert trigger.scope_resolver

      if trigger.kind == :poll do
        assert trigger.checkpoint
        assert trigger.dedupe
      end
    end

    namespace = inspect(module_namespace)

    for module <- provider.jido_action_modules() do
      assert String.starts_with?(inspect(module), namespace <> ".Actions.")
    end

    for module <- provider.jido_sensor_modules() do
      assert String.starts_with?(inspect(module), namespace <> ".Sensors.")

      assert module.trigger_id() in trigger_ids
      assert module.signal_type() == module.trigger_id()
      assert module.name() == String.replace(module.trigger_id(), ".", "_")
    end

    assert inspect(provider.jido_plugin_module()) == namespace <> ".Plugin"

    for pack <- provider.catalog_packs() do
      pack_id = Atom.to_string(pack.id)

      assert String.starts_with?(pack_id, pack_id_prefix)
      assert_present(pack.label)
      assert_present(pack.description)
      assert pack.filters == %{provider: spec.id}
      assert pack.metadata.package == spec.package
      assert Map.has_key?(pack.metadata, :risk) or Map.has_key?(pack.metadata, :excludes)

      if risk = Map.get(pack.metadata, :risk) do
        assert_known_risk(risk)
      end

      for excluded_tool <- Map.get(pack.metadata, :excludes, []) do
        assert MapSet.member?(tool_ids, excluded_tool)
      end

      for allowed_tool <- pack.allowed_tools do
        assert MapSet.member?(tool_ids, allowed_tool)
      end
    end
  end

  @doc "Asserts a product DSL fragment compiles as a Jido.Connect Spark fragment."
  def assert_spark_fragments(fragments) do
    for fragment <- fragments do
      assert {:module, ^fragment} = Code.ensure_loaded(fragment)
      assert fragment.extensions() == [Jido.Connect.Dsl.Extension]
      assert fragment.opts() == [of: Jido.Connect]
      assert %{extensions: [Jido.Connect.Dsl.Extension]} = fragment.persisted()
      assert is_map(fragment.spark_dsl_config())

      assert [{_section, Jido.Connect.Dsl.Extension, Jido.Connect.Dsl.Extension}] =
               fragment.validate_sections()
    end
  end

  @doc "Asserts the minimum scope resolver contract without replacing product-specific cases."
  def assert_scope_resolver_shape(resolver, expected_default_scopes) do
    expected_default_scopes = List.wrap(expected_default_scopes)

    assert function_exported?(resolver, :required_scopes, 3)
    assert resolver.required_scopes(%{}, %{}, %{}) == expected_default_scopes
    assert Enum.all?(expected_default_scopes, &is_binary/1)
  end

  @doc "Asserts a table of operation/scopes pairs against a scope resolver."
  def assert_scope_matrix(resolver, matrix) when is_list(matrix) do
    for row <- matrix do
      operation_id = Map.fetch!(row, :operation)
      scopes = Map.fetch!(row, :granted)
      expected = row |> Map.fetch!(:expected) |> List.wrap()
      label = Map.get(row, :label, operation_id)

      assert resolver.required_scopes(%{id: operation_id}, %{}, %{scopes: scopes}) == expected,
             label
    end
  end

  @doc "Asserts every action and trigger has reviewed privacy and risk metadata."
  def assert_privacy_matrix(provider, action_rows, trigger_rows \\ []) do
    spec = provider.integration()
    actions_by_id = Map.new(spec.actions, &{&1.id, &1})
    triggers_by_id = Map.new(spec.triggers, &{&1.id, &1})

    assert MapSet.new(Map.keys(actions_by_id)) == row_ids(action_rows)
    assert MapSet.new(Map.keys(triggers_by_id)) == row_ids(trigger_rows)

    for row <- action_rows do
      action = Map.fetch!(actions_by_id, Map.fetch!(row, :id))

      assert action.data_classification == Map.fetch!(row, :classification)
      assert action.risk == Map.fetch!(row, :risk)
      assert action.confirmation == Map.fetch!(row, :confirmation)

      assert_text_includes(action, Map.get(row, :text_includes, []))
    end

    for row <- trigger_rows do
      trigger = Map.fetch!(triggers_by_id, Map.fetch!(row, :id))

      assert trigger.data_classification == Map.fetch!(row, :classification)
      assert_text_includes(trigger, Map.get(row, :text_includes, []))
    end
  end

  @doc "Loads an offline JSON fixture as a map."
  def json_fixture!(path) do
    path
    |> File.read!()
    |> Jason.decode!()
  end

  @doc "Loads an offline Google fixture while keeping the product and filename explicit at call sites."
  def google_fixture!(product, name, caller_dir)
      when is_atom(product) and is_binary(name) and is_binary(caller_dir) do
    product
    |> google_fixture_root!()
    |> Path.join(name)
    |> Path.expand(caller_dir)
    |> json_fixture!()
  end

  @doc "Asserts Zoi-backed normalized structs expose required defaults and schemas."
  def assert_struct_defaults(module, attrs, expected_defaults) do
    assert {:module, ^module} = Code.ensure_loaded(module)
    assert function_exported?(module, :new, 1)
    assert function_exported?(module, :new!, 1)
    assert function_exported?(module, :schema, 0)

    struct = module.new!(attrs)
    assert %{__struct__: ^module} = struct

    for {field, expected_value} <- expected_defaults do
      assert Map.fetch!(struct, field) == expected_value
    end

    assert module.schema()
    struct
  end

  defp assert_google_tool_id(id, expected_prefix) do
    assert String.starts_with?(id, expected_prefix)
    assert Regex.match?(~r/\Agoogle\.[a-z0-9_]+(\.[a-z0-9_]+)+\z/, id)
  end

  defp assert_present(value) when is_binary(value), do: assert(String.trim(value) != "")
  defp assert_present(value), do: flunk("expected non-empty string, got: #{inspect(value)}")

  defp assert_known_data_classification(classification) do
    assert Taxonomy.known_data_classification?(classification)
  end

  defp assert_known_risk(risk) do
    assert Taxonomy.known_risk?(risk)
  end

  defp assert_known_confirmation(confirmation) do
    assert Taxonomy.known_confirmation?(confirmation)
  end

  defp assert_action_allow_list_availability(_plugin_module, %{actions: []}), do: :ok

  defp assert_action_allow_list_availability(plugin_module, spec) do
    [allowed_action | denied_actions] = spec.actions

    availability =
      plugin_module.tool_availability(%{allowed_actions: [allowed_action.id]})
      |> Map.new(&{&1.tool, &1})

    assert availability[allowed_action.id].state == :connection_required

    for action <- denied_actions do
      assert availability[action.id].state == :disabled_by_policy
    end

    for trigger <- spec.triggers do
      assert availability[trigger.id].state == :connection_required
    end
  end

  defp assert_trigger_allow_list_availability(_plugin_module, %{triggers: []}), do: :ok

  defp assert_trigger_allow_list_availability(plugin_module, spec) do
    [allowed_trigger | denied_triggers] = spec.triggers

    availability =
      plugin_module.tool_availability(%{allowed_triggers: [allowed_trigger.id]})
      |> Map.new(&{&1.tool, &1})

    assert availability[allowed_trigger.id].state == :connection_required

    for trigger <- denied_triggers do
      assert availability[trigger.id].state == :disabled_by_policy
    end

    for action <- spec.actions do
      assert availability[action.id].state == :connection_required
    end
  end

  defp assert_connected_availability(plugin_module, spec) do
    connection =
      Jido.Connect.Connection.new!(%{
        id: "#{spec.id}_conn",
        provider: spec.id,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: all_user_scopes(spec)
      })

    available = plugin_module.tool_availability(%{connection: connection})
    assert_availability_ids(available, Enum.map(spec.actions ++ spec.triggers, & &1.id))

    for availability <- available do
      assert availability.state == :available
      assert availability.connection_id == connection.id
      assert availability.missing_scopes == []
    end

    missing_scope_connection = %{connection | scopes: []}

    missing_scope_availability =
      plugin_module.tool_availability(%{connection: missing_scope_connection})

    assert Enum.any?(missing_scope_availability, &(&1.state == :missing_scopes))
    refute Enum.any?(missing_scope_availability, &(&1.state == :connection_required))
  end

  defp assert_availability_ids(availability, expected_ids) do
    assert MapSet.new(Enum.map(availability, & &1.tool)) == MapSet.new(expected_ids)
  end

  defp all_user_scopes(spec) do
    profile =
      Enum.find(spec.auth_profiles, &(&1.id == :user)) ||
        List.first(spec.auth_profiles)

    operation_scopes =
      spec.actions
      |> Enum.concat(spec.triggers)
      |> Enum.flat_map(& &1.scopes)

    profile.default_scopes
    |> Enum.concat(profile.optional_scopes)
    |> Enum.concat(operation_scopes)
    |> Enum.uniq()
  end

  defp row_ids(rows), do: rows |> Enum.map(&Map.fetch!(&1, :id)) |> MapSet.new()

  defp assert_text_includes(_operation, []), do: :ok

  defp assert_text_includes(operation, expected_fragments) do
    text =
      [operation.id, operation.label, Map.get(operation, :description)]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")
      |> String.downcase()

    for fragment <- expected_fragments do
      assert text =~ String.downcase(fragment)
    end
  end

  defp google_fixture_root!(product) do
    case Map.fetch(@google_fixture_roots, product) do
      {:ok, root} ->
        root

      :error ->
        products =
          @google_fixture_roots
          |> Map.keys()
          |> Enum.sort()
          |> Enum.map_join(", ", &inspect/1)

        raise ArgumentError,
              "unknown Google fixture product #{inspect(product)}; expected one of: #{products}"
    end
  end
end
