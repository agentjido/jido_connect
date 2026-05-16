defmodule Jido.Connect.CalendlyTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly

  test "declares Calendly provider metadata" do
    spec = Calendly.integration()

    assert spec.id == :calendly
    assert spec.package == :jido_connect_calendly
    assert spec.name == "Calendly"
    assert spec.category == :calendar
    assert spec.status == :experimental
    assert spec.tags == [:calendly, :scheduling, :booking, :webhooks]
    assert spec.actions == []
    assert spec.triggers == []

    assert [
             %{id: :personal_access_token, kind: :api_key} = pat_profile,
             %{id: :oauth2_user, kind: :oauth2} = oauth_profile
           ] =
             spec.auth_profiles

    assert pat_profile.default? == true
    assert oauth_profile.default? == false
    assert oauth_profile.pkce? == true
    assert "view" in oauth_profile.scopes
    assert "edit" in oauth_profile.scopes
    assert "webhook" in oauth_profile.scopes
  end

  test "compiles generated Jido plugin surface" do
    assert Application.get_env(:jido_connect_calendly, :jido_connect_providers) == [Calendly]
    assert Calendly.jido_action_modules() == []
    assert Calendly.jido_sensor_modules() == []
    assert Calendly.jido_plugin_module() == Jido.Connect.Calendly.Plugin

    assert %Jido.Connect.Catalog.Manifest{
             id: :calendly,
             package: :jido_connect_calendly,
             generated_modules: %{
               actions: [],
               sensors: [],
               plugin: Jido.Connect.Calendly.Plugin
             }
           } = Calendly.jido_connect_manifest()

    assert %Jido.Plugin.Spec{
             name: "calendly",
             module: Jido.Connect.Calendly.Plugin,
             actions: []
           } = Jido.Connect.Calendly.Plugin.plugin_spec()
  end

  test "exposes curated catalog pack delegates" do
    assert [%{id: :calendly_reader}] = Calendly.catalog_packs()
  end
end
