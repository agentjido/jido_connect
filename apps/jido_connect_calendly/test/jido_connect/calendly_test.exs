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

  test "declares ten actions (six read plus cancellation and webhooks)" do
    spec = Calendly.integration()

    action_ids = Enum.map(spec.actions, & &1.id)

    assert length(action_ids) == 10
    assert "calendly.event_types.list" in action_ids
    assert "calendly.event_types.get" in action_ids
    assert "calendly.scheduled_events.list" in action_ids
    assert "calendly.scheduled_events.get" in action_ids
    assert "calendly.invitees.list" in action_ids
    assert "calendly.invitees.get" in action_ids
    assert "calendly.invitees.cancel" in action_ids
    assert "calendly.webhooks.create" in action_ids
    assert "calendly.webhooks.list" in action_ids
    assert "calendly.webhooks.delete" in action_ids
  end

  test "compiles generated Jido plugin surface" do
    assert Application.get_env(:jido_connect_calendly, :jido_connect_providers) == [Calendly]
    assert length(Calendly.jido_action_modules()) == 10
    assert Calendly.jido_sensor_modules() == []
    assert Calendly.jido_plugin_module() == Jido.Connect.Calendly.Plugin

    assert %Jido.Connect.Catalog.Manifest{
             id: :calendly,
             package: :jido_connect_calendly,
             generated_modules: %{plugin: Jido.Connect.Calendly.Plugin}
           } = Calendly.jido_connect_manifest()

    assert %Jido.Plugin.Spec{
             name: "calendly",
             module: Jido.Connect.Calendly.Plugin
           } = Jido.Connect.Calendly.Plugin.plugin_spec()
  end

  test "exposes curated catalog pack delegates" do
    assert [%{id: :calendly_reader}, %{id: :calendly_webhook}, %{id: :calendly_full}] =
             Calendly.catalog_packs()
  end

  test "reader pack includes all six read action tools" do
    [%{id: :calendly_reader, allowed_tools: tools}] =
      Enum.filter(Calendly.catalog_packs(), &(&1.id == :calendly_reader))

    assert "calendly.event_types.list" in tools
    assert "calendly.event_types.get" in tools
    assert "calendly.scheduled_events.list" in tools
    assert "calendly.scheduled_events.get" in tools
    assert "calendly.invitees.list" in tools
    assert "calendly.invitees.get" in tools
  end
end
