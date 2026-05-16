defmodule Jido.Connect.SalesforceTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce

  @salesforce_read_fragment Jido.Connect.Salesforce.Actions.Read
  @salesforce_write_fragment Jido.Connect.Salesforce.Actions.Write

  @salesforce_action_modules [
    Jido.Connect.Salesforce.Actions.GetContact,
    Jido.Connect.Salesforce.Actions.ListContacts,
    Jido.Connect.Salesforce.Actions.Query,
    Jido.Connect.Salesforce.Actions.GetRecord,
    Jido.Connect.Salesforce.Actions.DescribeObject,
    Jido.Connect.Salesforce.Actions.ListRecent,
    Jido.Connect.Salesforce.Actions.QueryMore,
    Jido.Connect.Salesforce.Actions.CreateContact
  ]

  @salesforce_sensor_modules []

  @salesforce_dsl_fragments [
    @salesforce_read_fragment,
    @salesforce_write_fragment
  ]

  test "declares Salesforce provider metadata" do
    spec = Salesforce.integration()

    assert spec.id == :salesforce
    assert spec.package == :jido_connect_salesforce
    assert spec.name == "Salesforce"
    assert spec.category == :crm
    assert spec.status == :experimental
    assert spec.tags == [:salesforce, :crm, :contacts, :accounts, :opportunities]

    assert Enum.map(spec.actions, & &1.id) == [
             "salesforce.contacts.contact.get",
             "salesforce.contacts.contact.list",
             "salesforce.crm.query",
             "salesforce.crm.record.get",
             "salesforce.crm.object.describe",
             "salesforce.crm.record.list_recent",
             "salesforce.crm.query_more",
             "salesforce.contacts.contact.create"
           ]

    assert Enum.map(spec.triggers, & &1.id) == []

    assert [
             %{id: :oauth2_connected_app, kind: :oauth2} = oauth_profile,
             %{id: :username_password, kind: :oauth2} = pw_profile
           ] =
             spec.auth_profiles

    # OAuth connected-app is the default
    assert oauth_profile.default? == true
    assert oauth_profile.pkce? == true
    assert oauth_profile.refresh? == true
    assert "api" in oauth_profile.default_scopes
    assert "refresh_token,offline_access" in oauth_profile.default_scopes
    assert "cdp_api" in oauth_profile.optional_scopes
    assert :instance_url in oauth_profile.credential_fields

    # Username/password profile
    assert pw_profile.default? == false
    assert "api" in pw_profile.default_scopes
    assert :instance_url in pw_profile.credential_fields
  end

  test "compiles generated Jido plugin surface" do
    assert Application.get_env(:jido_connect_salesforce, :jido_connect_providers) ==
             [Salesforce]

    assert Salesforce.jido_action_modules() == @salesforce_action_modules
    assert Salesforce.jido_sensor_modules() == @salesforce_sensor_modules
    assert Salesforce.jido_plugin_module() == Jido.Connect.Salesforce.Plugin

    assert %Jido.Connect.Catalog.Manifest{
             id: :salesforce,
             package: :jido_connect_salesforce,
             generated_modules: %{
               actions: @salesforce_action_modules,
               sensors: @salesforce_sensor_modules,
               plugin: Jido.Connect.Salesforce.Plugin
             }
           } = Salesforce.jido_connect_manifest()

    assert %Jido.Plugin.Spec{
             name: "salesforce",
             module: Jido.Connect.Salesforce.Plugin,
             actions: @salesforce_action_modules
           } = Jido.Connect.Salesforce.Plugin.plugin_spec()
  end

  test "loads Salesforce Spark DSL fragments" do
    for fragment <- @salesforce_dsl_fragments do
      assert {:module, ^fragment} = Code.ensure_loaded(fragment)
      assert fragment.extensions() == [Jido.Connect.Dsl.Extension]
      assert fragment.opts() == [of: Jido.Connect]
      assert %{extensions: [Jido.Connect.Dsl.Extension]} = fragment.persisted()
      assert is_map(fragment.spark_dsl_config())

      assert [{_section, Jido.Connect.Dsl.Extension, Jido.Connect.Dsl.Extension}] =
               fragment.validate_sections()
    end
  end

  describe "plugin tool availability" do
    test "reports connection_required for all tools with no connection" do
      spec = Salesforce.integration()
      plugin_module = Salesforce.jido_plugin_module()
      tool_ids = Enum.map(spec.actions ++ spec.triggers, & &1.id)

      availability =
        plugin_module.tool_availability()
        |> Map.new(&{&1.tool, &1})

      assert MapSet.new(Map.keys(availability)) == MapSet.new(tool_ids)

      for {_tool, avail} <- availability do
        assert avail.state == :connection_required
      end
    end

    test "reports available when connected with full scopes" do
      spec = Salesforce.integration()
      plugin_module = Salesforce.jido_plugin_module()

      connection =
        Jido.Connect.Connection.new!(%{
          id: "sf_conn",
          provider: :salesforce,
          profile: :oauth2_connected_app,
          tenant_id: "tenant_1",
          owner_type: :app_user,
          owner_id: "user_1",
          status: :connected,
          scopes: all_salesforce_scopes(spec)
        })

      available =
        plugin_module.tool_availability(%{connection: connection})
        |> Map.new(&{&1.tool, &1})

      tool_ids = Enum.map(spec.actions ++ spec.triggers, & &1.id)
      assert MapSet.new(Map.keys(available)) == MapSet.new(tool_ids)

      for {_tool, avail} <- available do
        assert avail.state == :available
        assert avail.connection_id == connection.id
        assert avail.missing_scopes == []
      end
    end
  end

  defp all_salesforce_scopes(spec) do
    profile =
      Enum.find(spec.auth_profiles, &(&1.id == :oauth2_connected_app)) ||
        List.first(spec.auth_profiles)

    operation_scopes =
      spec.actions
      |> Enum.concat(spec.triggers)
      |> Enum.flat_map(& &1.scopes)

    profile.default_scopes
    |> Enum.concat(profile.scopes)
    |> Enum.concat(operation_scopes)
    |> Enum.uniq()
  end
end
