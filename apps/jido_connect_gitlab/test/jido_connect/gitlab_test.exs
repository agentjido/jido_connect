defmodule Jido.Connect.GitLabTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.GitLab

  test "declares GitLab provider metadata" do
    spec = GitLab.integration()

    assert spec.id == :gitlab
    assert spec.package == :jido_connect_gitlab
    assert spec.name == "GitLab"
    assert spec.category == :developer_tools
    assert spec.status == :experimental
    assert spec.tags == [:source_control, :issues, :developer_tools, :ci_cd]

    assert spec.actions == []
    assert spec.triggers == []

    assert [
             %{id: :oauth2_user, kind: :oauth2} = oauth_profile,
             %{id: :pat, kind: :api_key} = pat_profile
           ] =
             spec.auth_profiles

    assert oauth_profile.default? == true
    assert oauth_profile.pkce? == true
    assert oauth_profile.refresh? == true
    assert oauth_profile.revoke? == true
    assert "read_api" in oauth_profile.default_scopes
    assert "api" in oauth_profile.optional_scopes

    assert pat_profile.default? == false
    assert "read_api" in pat_profile.default_scopes
    assert "read_repository" in pat_profile.default_scopes
  end

  test "declares project_access policy" do
    spec = GitLab.integration()
    assert [%{id: :project_access, decision: :allow_operation}] = spec.policies
  end

  test "catalog entry exposes auth and runtime capabilities" do
    entry = Connect.Catalog.entry(GitLab)
    features = entry.capabilities |> Enum.map(& &1.feature) |> MapSet.new()

    assert entry.package == :jido_connect_gitlab
    assert entry.tags == [:source_control, :issues, :developer_tools, :ci_cd]
    assert [%{id: :project_access}] = entry.policies
    assert MapSet.member?(features, :oauth2)
    assert MapSet.member?(features, :api_key)
    assert MapSet.member?(features, :webhook_verification)
  end

  test "compiles generated Jido plugin surface with no actions" do
    assert Application.get_env(:jido_connect_gitlab, :jido_connect_providers) == [GitLab]

    assert GitLab.jido_action_modules() == []
    assert GitLab.jido_sensor_modules() == []
    assert GitLab.jido_plugin_module() == Jido.Connect.GitLab.Plugin

    assert %Connect.Catalog.Manifest{
             id: :gitlab,
             package: :jido_connect_gitlab,
             generated_modules: %{
               actions: [],
               sensors: [],
               plugin: Jido.Connect.GitLab.Plugin
             }
           } = GitLab.jido_connect_manifest()

    assert {:module, Jido.Connect.GitLab.Plugin} = Code.ensure_loaded(Jido.Connect.GitLab.Plugin)
    assert function_exported?(Jido.Connect.GitLab.Plugin, :plugin_spec, 1)
  end

  describe "plugin tool availability" do
    test "reports no tools when scaffold has no actions" do
      plugin_module = GitLab.jido_plugin_module()

      availability = plugin_module.tool_availability()
      assert availability == []
    end
  end
end
