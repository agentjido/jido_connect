defmodule Jido.Connect.InboundWebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.InboundWebhook
  alias Jido.Connect.InboundWebhook.Handlers.Triggers.InboundDeliveryWebhook, as: Handler
  alias Jido.Connect.TriggerSpec

  test "declares webhook provider metadata" do
    spec = InboundWebhook.integration()

    assert spec.id == :webhook
    assert spec.package == :jido_connect_webhook
    assert spec.name == "Webhook"
    assert spec.category == :tool_bridge
    assert spec.status == :available
    assert spec.tags == [:webhook, :verification, :infrastructure]

    assert spec.actions == []

    assert [%TriggerSpec{} = trigger] = spec.triggers
    assert trigger.id == "webhook.inbound.delivery"
    assert trigger.name == :inbound_delivery
    assert trigger.kind == :webhook
    assert trigger.handler == Handler
    assert trigger.resource == :delivery
    assert trigger.verb == :watch
    assert trigger.auth_profile == :signing_secret
    assert trigger.dedupe == %{key: [:delivery_id]}

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

    assert [Jido.Connect.InboundWebhook.Sensors.InboundDelivery] =
             InboundWebhook.jido_sensor_modules()

    assert InboundWebhook.jido_plugin_module() == Jido.Connect.InboundWebhook.Plugin

    assert %Jido.Connect.Catalog.Manifest{
             id: :webhook,
             package: :jido_connect_webhook,
             generated_modules: %{
               actions: [],
               sensors: [Jido.Connect.InboundWebhook.Sensors.InboundDelivery],
               plugin: Jido.Connect.InboundWebhook.Plugin
             }
           } = InboundWebhook.jido_connect_manifest()

    assert %Jido.Plugin.Spec{
             name: "webhook",
             module: Jido.Connect.InboundWebhook.Plugin,
             actions: []
           } = Jido.Connect.InboundWebhook.Plugin.plugin_spec()
  end

  test "plugin tool availability includes the inbound delivery trigger" do
    assert [%{tool: "webhook.inbound.delivery", state: :connection_required}] =
             Jido.Connect.InboundWebhook.Plugin.tool_availability()
  end
end
