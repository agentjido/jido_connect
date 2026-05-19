defmodule Jido.Connect.NotionTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Notion

  test "declares Notion provider metadata" do
    spec = Notion.integration()

    assert spec.id == :notion
    assert spec.package == :jido_connect_notion
    assert spec.name == "Notion"
    assert spec.category == :productivity
    assert spec.status == :experimental
    assert spec.tags == [:productivity, :documents, :databases, :notes, :knowledge]
    assert spec.actions == []
    assert spec.triggers == []

    assert [
             %{id: :internal_token, kind: :api_key} = token_profile,
             %{id: :oauth2, kind: :oauth2} = oauth_profile
           ] =
             spec.auth_profiles

    assert token_profile.default? == true
    assert "read_content" in token_profile.default_scopes
    assert "read_databases" in token_profile.default_scopes
    assert "read_users" in token_profile.default_scopes
    assert "insert_content" in token_profile.scopes
    assert "update_content" in token_profile.scopes
    assert "insert_databases" in token_profile.scopes

    assert oauth_profile.default? == false
    assert oauth_profile.pkce? == false
    assert oauth_profile.refresh? == false
  end

  test "declares workspace_access policy" do
    spec = Notion.integration()
    assert [%{id: :workspace_access, decision: :allow_operation}] = spec.policies
  end

  test "catalog entry exposes auth and runtime capabilities" do
    entry = Connect.Catalog.entry(Notion)
    features = entry.capabilities |> Enum.map(& &1.feature) |> MapSet.new()

    assert entry.package == :jido_connect_notion
    assert entry.tags == [:productivity, :documents, :databases, :notes, :knowledge]
    assert [%{id: :workspace_access}] = entry.policies
    assert MapSet.member?(features, :api_key)
    assert MapSet.member?(features, :api_access)
  end

  test "compiles generated Jido plugin surface with no actions" do
    assert Application.get_env(:jido_connect_notion, :jido_connect_providers) == [Notion]

    assert Notion.jido_action_modules() == []
    assert Notion.jido_sensor_modules() == []
    assert Notion.jido_plugin_module() == Jido.Connect.Notion.Plugin

    assert %Connect.Catalog.Manifest{
             id: :notion,
             package: :jido_connect_notion,
             generated_modules: generated
           } = Notion.jido_connect_manifest()

    assert generated.actions == []
    assert generated.sensors == []
    assert generated.plugin == Jido.Connect.Notion.Plugin

    assert %Jido.Plugin.Spec{
             name: "notion",
             module: Jido.Connect.Notion.Plugin,
             actions: []
           } = Jido.Connect.Notion.Plugin.plugin_spec()
  end

  describe "plugin tool availability" do
    test "reports empty availability with no actions" do
      plugin_module = Notion.jido_plugin_module()
      availability = plugin_module.tool_availability()
      assert availability == []
    end
  end
end
