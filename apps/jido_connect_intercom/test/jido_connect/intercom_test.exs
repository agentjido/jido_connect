defmodule Jido.Connect.IntercomTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Intercom

  test "declares Intercom provider metadata" do
    spec = Intercom.integration()

    assert spec.id == :intercom
    assert spec.package == :jido_connect_intercom
    assert spec.name == "Intercom"
    assert spec.category == :customer_support
    assert spec.status == :experimental
    assert spec.tags == [:support, :messaging, :customer_service]
    assert spec.actions == []
    assert spec.triggers == []

    assert [
             %{id: :access_token, kind: :api_key} = token_profile,
             %{id: :oauth2, kind: :oauth2} = oauth_profile
           ] =
             spec.auth_profiles

    assert token_profile.default? == true
    assert "contacts:read" in token_profile.default_scopes
    assert "conversations:read" in token_profile.default_scopes
    assert "companies:read" in token_profile.default_scopes
    assert "contacts:write" in token_profile.scopes
    assert "conversations:write" in token_profile.scopes

    assert oauth_profile.default? == false
    assert oauth_profile.pkce? == true
    assert oauth_profile.refresh? == false
  end

  test "declares workspace_access policy" do
    spec = Intercom.integration()
    assert [%{id: :workspace_access, decision: :allow_operation}] = spec.policies
  end

  test "catalog entry exposes auth and runtime capabilities" do
    entry = Connect.Catalog.entry(Intercom)
    features = entry.capabilities |> Enum.map(& &1.feature) |> MapSet.new()

    assert entry.package == :jido_connect_intercom
    assert entry.tags == [:support, :messaging, :customer_service]
    assert [%{id: :workspace_access}] = entry.policies
    assert MapSet.member?(features, :api_key)
    assert MapSet.member?(features, :api_access)
  end

  test "compiles generated Jido plugin surface with no actions" do
    assert Application.get_env(:jido_connect_intercom, :jido_connect_providers) == [Intercom]

    assert Intercom.jido_action_modules() == []
    assert Intercom.jido_sensor_modules() == []
    assert Intercom.jido_plugin_module() == Jido.Connect.Intercom.Plugin

    assert %Connect.Catalog.Manifest{
             id: :intercom,
             package: :jido_connect_intercom,
             generated_modules: generated
           } = Intercom.jido_connect_manifest()

    assert generated.actions == []
    assert generated.sensors == []
    assert generated.plugin == Jido.Connect.Intercom.Plugin

    assert %Jido.Plugin.Spec{
             name: "intercom",
             module: Jido.Connect.Intercom.Plugin,
             actions: []
           } = Jido.Connect.Intercom.Plugin.plugin_spec()
  end

  describe "plugin tool availability" do
    test "reports empty availability with no actions" do
      plugin_module = Intercom.jido_plugin_module()
      availability = plugin_module.tool_availability()
      assert availability == []
    end
  end
end
