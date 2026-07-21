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
    assert length(spec.actions) == 15
    assert length(spec.triggers) == 8

    trigger_ids = Enum.map(spec.triggers, & &1.id)
    assert "intercom.conversation.user.created" in trigger_ids
    assert "intercom.conversation.admin.replied" in trigger_ids
    assert "intercom.conversation.user.replied" in trigger_ids
    assert "intercom.conversation.admin.assigned" in trigger_ids
    assert "intercom.conversation.admin.closed" in trigger_ids
    assert "intercom.contact.created" in trigger_ids
    assert "intercom.contact.updated" in trigger_ids
    assert "intercom.contact.deleted" in trigger_ids

    action_ids = Enum.map(spec.actions, & &1.id)
    assert "intercom.contact.list" in action_ids
    assert "intercom.contact.search" in action_ids
    assert "intercom.contact.get" in action_ids
    assert "intercom.contact.create" in action_ids
    assert "intercom.contact.update" in action_ids
    assert "intercom.contact.tag" in action_ids
    assert "intercom.contact.untag" in action_ids
    assert "intercom.conversation.list" in action_ids
    assert "intercom.conversation.search" in action_ids
    assert "intercom.conversation.get" in action_ids
    assert "intercom.conversation.reply" in action_ids
    assert "intercom.conversation.add_note" in action_ids
    assert "intercom.conversation.assign" in action_ids
    assert "intercom.admin.list" in action_ids
    assert "intercom.team.list" in action_ids

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

  test "compiles generated Jido plugin surface with read actions" do
    assert Application.get_env(:jido_connect_intercom, :jido_connect_providers) == [Intercom]

    action_modules = Intercom.jido_action_modules()
    assert length(action_modules) == 15
    assert length(Intercom.jido_sensor_modules()) == 8
    assert Intercom.jido_plugin_module() == Jido.Connect.Intercom.Plugin

    assert %Connect.Catalog.Manifest{
             id: :intercom,
             package: :jido_connect_intercom,
             generated_modules: generated
           } = Intercom.jido_connect_manifest()

    assert length(generated.actions) == 15
    assert length(generated.sensors) == 8
    assert generated.plugin == Jido.Connect.Intercom.Plugin

    assert %Jido.Plugin.Spec{
             name: "intercom",
             module: Jido.Connect.Intercom.Plugin,
             actions: actions
           } = Jido.Connect.Intercom.Plugin.plugin_spec()

    assert length(actions) == 15
  end

  describe "plugin tool availability" do
    test "reports availability for all actions and triggers" do
      plugin_module = Intercom.jido_plugin_module()
      availability = plugin_module.tool_availability()
      assert length(availability) == 23

      tool_ids = Enum.map(availability, & &1.tool)
      # Actions (15)
      assert "intercom.contact.list" in tool_ids
      assert "intercom.contact.search" in tool_ids
      assert "intercom.contact.get" in tool_ids
      assert "intercom.contact.create" in tool_ids
      assert "intercom.contact.update" in tool_ids
      assert "intercom.contact.tag" in tool_ids
      assert "intercom.contact.untag" in tool_ids
      assert "intercom.conversation.list" in tool_ids
      assert "intercom.conversation.search" in tool_ids
      assert "intercom.conversation.get" in tool_ids
      assert "intercom.conversation.reply" in tool_ids
      assert "intercom.conversation.add_note" in tool_ids
      assert "intercom.conversation.assign" in tool_ids
      assert "intercom.admin.list" in tool_ids
      assert "intercom.team.list" in tool_ids
      # Triggers (8)
      assert "intercom.conversation.user.created" in tool_ids
      assert "intercom.conversation.admin.replied" in tool_ids
      assert "intercom.conversation.user.replied" in tool_ids
      assert "intercom.conversation.admin.assigned" in tool_ids
      assert "intercom.conversation.admin.closed" in tool_ids
      assert "intercom.contact.created" in tool_ids
      assert "intercom.contact.updated" in tool_ids
      assert "intercom.contact.deleted" in tool_ids
    end
  end
end
