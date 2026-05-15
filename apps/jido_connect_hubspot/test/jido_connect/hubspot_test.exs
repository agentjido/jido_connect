defmodule Jido.Connect.HubSpotTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot

  @hubspot_action_modules []

  @hubspot_dsl_fragments []

  test "declares HubSpot provider metadata" do
    spec = HubSpot.integration()

    assert spec.id == :hubspot
    assert spec.package == :jido_connect_hubspot
    assert spec.name == "HubSpot"
    assert spec.category == :crm
    assert spec.status == :experimental
    assert spec.tags == [:hubspot, :crm, :contacts, :deals]

    assert Enum.map(spec.actions, & &1.id) == []
    assert Enum.map(spec.triggers, & &1.id) == []

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
    assert HubSpot.jido_sensor_modules() == []
    assert HubSpot.jido_plugin_module() == Jido.Connect.HubSpot.Plugin

    assert %Jido.Connect.Catalog.Manifest{
             id: :hubspot,
             package: :jido_connect_hubspot,
             generated_modules: %{
               actions: [],
               sensors: [],
               plugin: Jido.Connect.HubSpot.Plugin
             }
           } = HubSpot.jido_connect_manifest()

    assert %Jido.Plugin.Spec{
             name: "hubspot",
             module: Jido.Connect.HubSpot.Plugin,
             actions: []
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
end
