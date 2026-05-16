defmodule Jido.Connect.InboundWebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.InboundWebhook

  test "declares webhook provider metadata" do
    spec = InboundWebhook.integration()

    assert spec.id == :webhook
    assert spec.package == :jido_connect_webhook
    assert spec.name == "Webhook"
    assert spec.category == :tool_bridge
    assert spec.status == :available
    assert spec.tags == [:webhook, :verification, :infrastructure]

    assert spec.actions == []
    assert spec.triggers == []

    assert [%{id: :signing_secret, kind: :api_key} = profile] =
             spec.auth_profiles

    assert profile.default? == true
    assert profile.owner == :tenant
    assert profile.subject == :webhook
    assert profile.label == "Webhook signing secret"
    assert profile.setup == :api_key_shared_secret
    assert profile.credential_fields == [:signing_secret]
    assert profile.lease_fields == [:signing_secret]
    assert profile.scopes == []
    assert profile.default_scopes == []
  end

  test "compiles generated Jido plugin surface" do
    assert Application.get_env(:jido_connect_webhook, :jido_connect_providers) == [
             InboundWebhook
         ]

    assert InboundWebhook.jido_action_modules() == []
    assert InboundWebhook.jido_sensor_modules() == []
    assert InboundWebhook.jido_plugin_module() == Jido.Connect.InboundWebhook.Plugin

    assert %Jido.Connect.Catalog.Manifest{
             id: :webhook,
             package: :jido_connect_webhook,
             generated_modules: %{
               actions: [],
               sensors: [],
               plugin: Jido.Connect.InboundWebhook.Plugin
             }
           } = InboundWebhook.jido_connect_manifest()

    assert %Jido.Plugin.Spec{
             name: "webhook",
             module: Jido.Connect.InboundWebhook.Plugin,
             actions: []
           } = Jido.Connect.InboundWebhook.Plugin.plugin_spec()
  end

  test "plugin tool availability returns empty list with no actions or triggers" do
    assert [] = Jido.Connect.InboundWebhook.Plugin.tool_availability()
  end
end
