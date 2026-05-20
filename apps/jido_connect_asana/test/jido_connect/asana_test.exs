defmodule Jido.Connect.AsanaTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Asana

  test "declares Asana provider metadata" do
    spec = Asana.integration()

    assert spec.id == :asana
    assert spec.package == :jido_connect_asana
    assert spec.name == "Asana"
    assert spec.category == :project_management
    assert spec.status == :experimental
    assert spec.tags == [:work_management, :tasks, :projects, :collaboration]
    assert length(spec.actions) == 8
    assert spec.triggers == []

    action_ids = Enum.map(spec.actions, & &1.id)

    assert "asana.workspace.list" in action_ids
    assert "asana.project.list" in action_ids
    assert "asana.task.list" in action_ids
    assert "asana.task.get" in action_ids
    assert "asana.task.search" in action_ids
    assert "asana.story.list" in action_ids
    assert "asana.user.get" in action_ids
    assert "asana.user.list" in action_ids

    assert [
             %{id: :pat, kind: :api_key} = pat_profile,
             %{id: :oauth2, kind: :oauth2} = oauth_profile
           ] =
             spec.auth_profiles

    assert pat_profile.default? == true
    assert "default" in pat_profile.default_scopes
    assert "read" in pat_profile.default_scopes
    assert "write" in pat_profile.scopes

    assert oauth_profile.default? == false
    assert oauth_profile.pkce? == false
    assert oauth_profile.refresh? == true
    assert "default" in oauth_profile.default_scopes
    assert "read" in oauth_profile.default_scopes
    assert "write" in oauth_profile.optional_scopes
  end

  test "declares workspace_access policy" do
    spec = Asana.integration()
    assert [%{id: :workspace_access, decision: :allow_operation}] = spec.policies
  end

  test "catalog entry exposes auth and runtime capabilities" do
    entry = Connect.Catalog.entry(Asana)
    features = entry.capabilities |> Enum.map(& &1.feature) |> MapSet.new()

    assert entry.package == :jido_connect_asana
    assert entry.tags == [:work_management, :tasks, :projects, :collaboration]
    assert [%{id: :workspace_access}] = entry.policies
    assert MapSet.member?(features, :api_key)
    assert MapSet.member?(features, :api_access)
  end

  test "compiles generated Jido plugin surface with 8 read actions" do
    assert Application.get_env(:jido_connect_asana, :jido_connect_providers) == [Asana]

    action_modules = Asana.jido_action_modules()
    assert length(action_modules) == 8

    assert Asana.jido_sensor_modules() == []
    assert Asana.jido_plugin_module() == Jido.Connect.Asana.Plugin

    assert %Connect.Catalog.Manifest{
             id: :asana,
             package: :jido_connect_asana,
             generated_modules: generated
           } = Asana.jido_connect_manifest()

    assert length(generated.actions) == 8
    assert generated.sensors == []
    assert generated.plugin == Jido.Connect.Asana.Plugin

    assert %Jido.Plugin.Spec{
             name: "asana",
             module: Jido.Connect.Asana.Plugin,
             actions: actions
           } = Jido.Connect.Asana.Plugin.plugin_spec()

    assert length(actions) == 8
  end

  describe "plugin tool availability" do
    test "reports availability for 8 read actions" do
      plugin_module = Asana.jido_plugin_module()
      availability = plugin_module.tool_availability()
      assert length(availability) == 8
    end
  end
end
