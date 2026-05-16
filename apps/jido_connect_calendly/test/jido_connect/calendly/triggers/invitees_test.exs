defmodule Jido.Connect.Calendly.Triggers.InviteesTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly

  @fragment Jido.Connect.Calendly.Triggers.Invitees

  test "is a valid Spark DSL fragment" do
    assert {:module, @fragment} = Code.ensure_loaded(@fragment)
    assert @fragment.extensions() == [Jido.Connect.Dsl.Extension]
    assert @fragment.opts() == [of: Jido.Connect]
    assert %{extensions: [Jido.Connect.Dsl.Extension]} = @fragment.persisted()
  end

  test "declares invitee created trigger" do
    spec = Calendly.integration()

    trigger = Enum.find(spec.triggers, &(&1.id == "calendly.invitee.created"))

    assert trigger != nil
    assert trigger.resource == :invitee
    assert trigger.verb == :watch
    assert trigger.kind == :webhook
    assert trigger.label == "Invitee created"
    assert trigger.handler == Jido.Connect.Calendly.Handlers.Triggers.InviteeCreatedWebhook
  end

  test "invitee created trigger has verification config" do
    spec = Calendly.integration()

    trigger = Enum.find(spec.triggers, &(&1.id == "calendly.invitee.created"))

    assert trigger.verification.kind == :calendly_webhook
    assert trigger.verification.signature == :hmac_sha256
    assert trigger.verification.header == "Calendly-Webhook-Signature"
  end

  test "invitee created trigger has dedupe config" do
    spec = Calendly.integration()

    trigger = Enum.find(spec.triggers, &(&1.id == "calendly.invitee.created"))

    assert trigger.dedupe.key == [:invitee_uri, :time]
  end

  test "invitee created trigger has signal fields" do
    spec = Calendly.integration()

    trigger = Enum.find(spec.triggers, &(&1.id == "calendly.invitee.created"))
    signal_names = Enum.map(trigger.signal, & &1.name)

    assert :event_type in signal_names
    assert :change_type in signal_names
    assert :invitee_uri in signal_names
    assert :invitee_email in signal_names
    assert :invitee_name in signal_names
    assert :invitee_status in signal_names
    assert :event_uri in signal_names
    assert :event_type_uri in signal_names
    assert :event_type_name in signal_names
    assert :organization_uri in signal_names
    assert :created_at in signal_names
    assert :updated_at in signal_names
    assert :time in signal_names
  end

  test "invitee created trigger uses personal_access_token auth" do
    spec = Calendly.integration()

    trigger = Enum.find(spec.triggers, &(&1.id == "calendly.invitee.created"))
    assert trigger.auth_profile == :personal_access_token
  end

  test "invitee created trigger has scope resolver" do
    spec = Calendly.integration()

    trigger = Enum.find(spec.triggers, &(&1.id == "calendly.invitee.created"))
    assert trigger.scope_resolver == Jido.Connect.Calendly.ScopeResolver
  end

  test "declares invitee canceled trigger" do
    spec = Calendly.integration()

    trigger = Enum.find(spec.triggers, &(&1.id == "calendly.invitee.canceled"))

    assert trigger != nil
    assert trigger.resource == :invitee
    assert trigger.verb == :watch
    assert trigger.kind == :webhook
    assert trigger.label == "Invitee canceled"
    assert trigger.handler == Jido.Connect.Calendly.Handlers.Triggers.InviteeCanceledWebhook
  end

  test "invitee canceled trigger has verification config" do
    spec = Calendly.integration()

    trigger = Enum.find(spec.triggers, &(&1.id == "calendly.invitee.canceled"))

    assert trigger.verification.kind == :calendly_webhook
    assert trigger.verification.signature == :hmac_sha256
    assert trigger.verification.header == "Calendly-Webhook-Signature"
  end

  test "invitee canceled trigger has dedupe config" do
    spec = Calendly.integration()

    trigger = Enum.find(spec.triggers, &(&1.id == "calendly.invitee.canceled"))

    assert trigger.dedupe.key == [:invitee_uri, :time]
  end

  test "invitee canceled trigger has cancellation signal fields" do
    spec = Calendly.integration()

    trigger = Enum.find(spec.triggers, &(&1.id == "calendly.invitee.canceled"))
    signal_names = Enum.map(trigger.signal, & &1.name)

    assert :event_type in signal_names
    assert :change_type in signal_names
    assert :invitee_uri in signal_names
    assert :canceled_by in signal_names
    assert :cancellation_reason in signal_names
    assert :created_at in signal_names
    assert :updated_at in signal_names
    assert :time in signal_names
  end

  test "invitee canceled trigger uses personal_access_token auth" do
    spec = Calendly.integration()

    trigger = Enum.find(spec.triggers, &(&1.id == "calendly.invitee.canceled"))
    assert trigger.auth_profile == :personal_access_token
  end

  test "invitee canceled trigger has scope resolver" do
    spec = Calendly.integration()

    trigger = Enum.find(spec.triggers, &(&1.id == "calendly.invitee.canceled"))
    assert trigger.scope_resolver == Jido.Connect.Calendly.ScopeResolver
  end

  test "provider declares exactly two triggers" do
    spec = Calendly.integration()

    trigger_ids = Enum.map(spec.triggers, & &1.id)

    assert length(trigger_ids) == 2
    assert "calendly.invitee.created" in trigger_ids
    assert "calendly.invitee.canceled" in trigger_ids
  end
end
