defmodule Jido.Connect.ZendeskTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Zendesk

  test "declares Zendesk provider metadata" do
    spec = Zendesk.integration()

    assert spec.id == :zendesk
    assert spec.package == :jido_connect_zendesk
    assert spec.name == "Zendesk"
    assert spec.category == :customer_support
    assert spec.status == :experimental
    assert spec.tags == [:support, :tickets, :customer_service]
    assert length(spec.actions) == 9
    assert spec.triggers == []

    action_ids = Enum.map(spec.actions, & &1.id)
    assert "zendesk.ticket.list" in action_ids
    assert "zendesk.ticket.search" in action_ids
    assert "zendesk.ticket.get" in action_ids
    assert "zendesk.ticket.create" in action_ids
    assert "zendesk.ticket.update" in action_ids
    assert "zendesk.ticket.comment.list" in action_ids
    assert "zendesk.ticket.comment.add" in action_ids
    assert "zendesk.user.list" in action_ids
    assert "zendesk.organization.list" in action_ids

    assert [
             %{id: :api_token, kind: :api_key} = api_token_profile,
             %{id: :oauth2, kind: :oauth2} = oauth_profile
           ] =
             spec.auth_profiles

    assert api_token_profile.default? == true
    assert "read" in api_token_profile.default_scopes
    assert "write" in api_token_profile.scopes
    assert "tickets:read" in api_token_profile.default_scopes

    assert oauth_profile.default? == false
    assert oauth_profile.pkce? == true
    assert oauth_profile.refresh? == true
    assert "read" in oauth_profile.default_scopes
    assert "write" in oauth_profile.optional_scopes
  end

  test "declares instance_access policy" do
    spec = Zendesk.integration()
    assert [%{id: :instance_access, decision: :allow_operation}] = spec.policies
  end

  test "catalog entry exposes auth and runtime capabilities" do
    entry = Connect.Catalog.entry(Zendesk)
    features = entry.capabilities |> Enum.map(& &1.feature) |> MapSet.new()

    assert entry.package == :jido_connect_zendesk
    assert entry.tags == [:support, :tickets, :customer_service]
    assert [%{id: :instance_access}] = entry.policies
    assert MapSet.subset?(MapSet.new([:api_key, :oauth2]), features)
    assert MapSet.member?(features, :api_access)
  end

  test "compiles generated Jido plugin surface with ticket read actions" do
    assert Application.get_env(:jido_connect_zendesk, :jido_connect_providers) == [Zendesk]

    action_modules = Zendesk.jido_action_modules()
    assert length(action_modules) == 9
    assert Zendesk.jido_sensor_modules() == []
    assert Zendesk.jido_plugin_module() == Jido.Connect.Zendesk.Plugin

    assert %Connect.Catalog.Manifest{
             id: :zendesk,
             package: :jido_connect_zendesk,
             generated_modules: generated
           } = Zendesk.jido_connect_manifest()

    assert length(generated.actions) == 9
    assert generated.sensors == []
    assert generated.plugin == Jido.Connect.Zendesk.Plugin

    assert %Jido.Plugin.Spec{
             name: "zendesk",
             module: Jido.Connect.Zendesk.Plugin,
             actions: actions
           } = Jido.Connect.Zendesk.Plugin.plugin_spec()

    assert length(actions) == 9
  end

  describe "plugin tool availability" do
    test "reports connection_required with no connection" do
      plugin_module = Zendesk.jido_plugin_module()

      availability = plugin_module.tool_availability()
      assert length(availability) == 9

      for entry <- availability do
        assert entry.state == :connection_required
        assert entry.connection_id == nil
      end
    end

    test "reports available when connected with full scopes" do
      spec = Zendesk.integration()
      plugin_module = Zendesk.jido_plugin_module()

      connection =
        Connect.Connection.new!(%{
          id: "zendesk_conn",
          provider: :zendesk,
          profile: :api_token,
          tenant_id: "tenant_1",
          owner_type: :app_user,
          owner_id: "user_1",
          status: :connected,
          scopes: all_zendesk_scopes(spec)
        })

      available =
        plugin_module.tool_availability(%{connection: connection})
        |> Map.new(&{&1.tool, &1})

      # 9 actions should be available with full scopes
      assert map_size(available) == 9

      assert Map.has_key?(available, "zendesk.ticket.list")
      assert Map.has_key?(available, "zendesk.ticket.search")
      assert Map.has_key?(available, "zendesk.ticket.get")
      assert Map.has_key?(available, "zendesk.ticket.create")
      assert Map.has_key?(available, "zendesk.ticket.update")
      assert Map.has_key?(available, "zendesk.ticket.comment.list")
      assert Map.has_key?(available, "zendesk.ticket.comment.add")
      assert Map.has_key?(available, "zendesk.user.list")
      assert Map.has_key?(available, "zendesk.organization.list")
    end
  end

  defp all_zendesk_scopes(spec) do
    profile =
      Enum.find(spec.auth_profiles, &(&1.id == :api_token)) ||
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
