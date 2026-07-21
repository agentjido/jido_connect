defmodule Jido.Connect.HubSpotTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot

  @hubspot_read_fragment Jido.Connect.HubSpot.Actions.Read
  @hubspot_write_fragment Jido.Connect.HubSpot.Actions.Write
  @hubspot_contacts_triggers_fragment Jido.Connect.HubSpot.Triggers.Contacts
  @hubspot_deals_triggers_fragment Jido.Connect.HubSpot.Triggers.Deals

  @hubspot_action_modules [
    Jido.Connect.HubSpot.Actions.GetContact,
    Jido.Connect.HubSpot.Actions.ListContacts,
    Jido.Connect.HubSpot.Actions.SearchContacts,
    Jido.Connect.HubSpot.Actions.GetCompany,
    Jido.Connect.HubSpot.Actions.ListCompanies,
    Jido.Connect.HubSpot.Actions.SearchCompanies,
    Jido.Connect.HubSpot.Actions.GetDeal,
    Jido.Connect.HubSpot.Actions.ListDeals,
    Jido.Connect.HubSpot.Actions.SearchDeals,
    Jido.Connect.HubSpot.Actions.CreateContact,
    Jido.Connect.HubSpot.Actions.UpdateContact,
    Jido.Connect.HubSpot.Actions.CreateDeal,
    Jido.Connect.HubSpot.Actions.UpdateDeal,
    Jido.Connect.HubSpot.Actions.CreateNote
  ]

  @hubspot_sensor_modules [
    Jido.Connect.HubSpot.Sensors.ContactChanged,
    Jido.Connect.HubSpot.Sensors.ContactChangedPush,
    Jido.Connect.HubSpot.Sensors.DealChanged,
    Jido.Connect.HubSpot.Sensors.DealChangedPush
  ]

  @hubspot_dsl_fragments [
    @hubspot_read_fragment,
    @hubspot_write_fragment,
    @hubspot_contacts_triggers_fragment,
    @hubspot_deals_triggers_fragment
  ]

  test "declares HubSpot provider metadata" do
    spec = HubSpot.integration()

    assert spec.id == :hubspot
    assert spec.package == :jido_connect_hubspot
    assert spec.name == "HubSpot"
    assert spec.category == :crm
    assert spec.status == :experimental
    assert spec.tags == [:hubspot, :crm, :contacts, :deals]

    assert Enum.map(spec.actions, & &1.id) == [
             "hubspot.contacts.contact.get",
             "hubspot.contacts.contact.list",
             "hubspot.contacts.contact.search",
             "hubspot.companies.company.get",
             "hubspot.companies.company.list",
             "hubspot.companies.company.search",
             "hubspot.deals.deal.get",
             "hubspot.deals.deal.list",
             "hubspot.deals.deal.search",
             "hubspot.contacts.contact.create",
             "hubspot.contacts.contact.update",
             "hubspot.deals.deal.create",
             "hubspot.deals.deal.update",
             "hubspot.notes.note.create"
           ]

    assert Enum.map(spec.triggers, & &1.id) == [
             "hubspot.contacts.contact.changed",
             "hubspot.contacts.contact.changed.push",
             "hubspot.deals.deal.changed",
             "hubspot.deals.deal.changed.push"
           ]

    assert [
             %{id: :private_app_token, kind: :api_key} = pat_profile,
             %{id: :oauth2_user, kind: :oauth2} = oauth_profile
           ] =
             spec.auth_profiles

    assert pat_profile.default? == true
    assert "crm.objects.contacts.read" in pat_profile.default_scopes
    assert "crm.objects.contacts.write" in pat_profile.scopes

    assert oauth_profile.default? == false
    assert oauth_profile.pkce? == true
    assert oauth_profile.refresh? == true
    assert "crm.objects.contacts.read" in oauth_profile.default_scopes
    assert "crm.objects.contacts.write" in oauth_profile.optional_scopes
  end

  test "compiles generated Jido plugin surface" do
    assert Application.get_env(:jido_connect_hubspot, :jido_connect_providers) == [HubSpot]

    assert HubSpot.jido_action_modules() == @hubspot_action_modules
    assert HubSpot.jido_sensor_modules() == @hubspot_sensor_modules
    assert HubSpot.jido_plugin_module() == Jido.Connect.HubSpot.Plugin

    assert %Jido.Connect.Catalog.Manifest{
             id: :hubspot,
             package: :jido_connect_hubspot,
             generated_modules: %{
               actions: @hubspot_action_modules,
               sensors: @hubspot_sensor_modules,
               plugin: Jido.Connect.HubSpot.Plugin
             }
           } = HubSpot.jido_connect_manifest()

    assert %Jido.Plugin.Spec{
             name: "hubspot",
             module: Jido.Connect.HubSpot.Plugin,
             actions: @hubspot_action_modules
           } = Jido.Connect.HubSpot.Plugin.plugin_spec()
  end

  test "loads HubSpot Spark DSL fragments" do
    for fragment <- @hubspot_dsl_fragments do
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
      spec = HubSpot.integration()
      plugin_module = HubSpot.jido_plugin_module()
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
      spec = HubSpot.integration()
      plugin_module = HubSpot.jido_plugin_module()

      connection =
        Jido.Connect.Connection.new!(%{
          id: "hubspot_conn",
          provider: :hubspot,
          profile: :private_app_token,
          tenant_id: "tenant_1",
          owner_type: :app_user,
          owner_id: "user_1",
          status: :connected,
          scopes: all_hubspot_scopes(spec)
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

    test "reports missing_scopes when connected without write scopes" do
      spec = HubSpot.integration()
      plugin_module = HubSpot.jido_plugin_module()

      read_scopes = [
        "crm.objects.contacts.read",
        "crm.objects.companies.read",
        "crm.objects.deals.read",
        "crm.objects.tickets.read"
      ]

      connection =
        Jido.Connect.Connection.new!(%{
          id: "hubspot_readonly_conn",
          provider: :hubspot,
          profile: :private_app_token,
          tenant_id: "tenant_1",
          owner_type: :app_user,
          owner_id: "user_1",
          status: :connected,
          scopes: read_scopes
        })

      availability =
        plugin_module.tool_availability(%{connection: connection})
        |> Map.new(&{&1.tool, &1})

      # Read actions should be available
      read_actions = Enum.filter(spec.actions, &(&1.risk == :read))

      for action <- read_actions do
        assert availability[action.id].state == :available
      end

      # Write actions should report missing scopes
      write_actions = Enum.filter(spec.actions, &(&1.risk == :write))

      for action <- write_actions do
        assert availability[action.id].state == :missing_scopes
        assert length(availability[action.id].missing_scopes) > 0
      end
    end
  end

  defp all_hubspot_scopes(spec) do
    profile =
      Enum.find(spec.auth_profiles, &(&1.id == :private_app_token)) ||
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
