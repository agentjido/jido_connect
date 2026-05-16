defmodule Jido.Connect.Calendly.Actions.CancellationWebhooksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly

  @fragment Jido.Connect.Calendly.Actions.CancellationWebhooks

  test "is a valid Spark DSL fragment" do
    assert {:module, @fragment} = Code.ensure_loaded(@fragment)
    assert @fragment.extensions() == [Jido.Connect.Dsl.Extension]
    assert @fragment.opts() == [of: Jido.Connect]
    assert %{extensions: [Jido.Connect.Dsl.Extension]} = @fragment.persisted()
  end

  test "declares cancel invitee action" do
    spec = Calendly.integration()

    action = Enum.find(spec.actions, &(&1.id == "calendly.invitees.cancel"))

    assert action != nil
    assert action.resource == :invitee
    assert action.verb == :update
    assert action.handler == Jido.Connect.Calendly.Handlers.Actions.CancelInvitee
  end

  test "cancel invitee action has required inputs" do
    spec = Calendly.integration()

    action = Enum.find(spec.actions, &(&1.id == "calendly.invitees.cancel"))
    input_names = Enum.map(action.input, & &1.name)

    assert :event_uri in input_names
    assert :uri in input_names
    assert :reason in input_names

    event_uri_field = Enum.find(action.input, &(&1.name == :event_uri))
    assert event_uri_field.required? == true

    uri_field = Enum.find(action.input, &(&1.name == :uri))
    assert uri_field.required? == true

    reason_field = Enum.find(action.input, &(&1.name == :reason))
    assert reason_field.required? == false
  end

  test "cancel invitee action is mutating with confirmation" do
    spec = Calendly.integration()

    action = Enum.find(spec.actions, &(&1.id == "calendly.invitees.cancel"))
    assert action.mutation? == true
  end

  test "cancel invitee action has risk metadata" do
    spec = Calendly.integration()

    action = Enum.find(spec.actions, &(&1.id == "calendly.invitees.cancel"))
    assert action.metadata.risk_tags == [:cancellation, :mutation]
  end

  test "declares webhook create action" do
    spec = Calendly.integration()

    action = Enum.find(spec.actions, &(&1.id == "calendly.webhooks.create"))

    assert action != nil
    assert action.resource == :webhook_subscription
    assert action.verb == :create
    assert action.handler == Jido.Connect.Calendly.Handlers.Actions.CreateWebhook
  end

  test "webhook create action has required inputs" do
    spec = Calendly.integration()

    action = Enum.find(spec.actions, &(&1.id == "calendly.webhooks.create"))
    input_names = Enum.map(action.input, & &1.name)

    assert :callback_url in input_names
    assert :events in input_names
    assert :organization_uri in input_names
    assert :user_uri in input_names
    assert :scope in input_names

    callback_url_field = Enum.find(action.input, &(&1.name == :callback_url))
    assert callback_url_field.required? == true

    events_field = Enum.find(action.input, &(&1.name == :events))
    assert events_field.required? == true
  end

  test "declares webhook list action" do
    spec = Calendly.integration()

    action = Enum.find(spec.actions, &(&1.id == "calendly.webhooks.list"))

    assert action != nil
    assert action.resource == :webhook_subscription
    assert action.verb == :list
    assert action.handler == Jido.Connect.Calendly.Handlers.Actions.ListWebhooks
  end

  test "webhook list action has pagination fields" do
    spec = Calendly.integration()

    action = Enum.find(spec.actions, &(&1.id == "calendly.webhooks.list"))
    input_names = Enum.map(action.input, & &1.name)

    assert :count in input_names
    assert :page_token in input_names

    count_field = Enum.find(action.input, &(&1.name == :count))
    assert count_field.default == 20
  end

  test "declares webhook delete action" do
    spec = Calendly.integration()

    action = Enum.find(spec.actions, &(&1.id == "calendly.webhooks.delete"))

    assert action != nil
    assert action.resource == :webhook_subscription
    assert action.verb == :delete
    assert action.handler == Jido.Connect.Calendly.Handlers.Actions.DeleteWebhook
  end

  test "webhook delete action has required URI input" do
    spec = Calendly.integration()

    action = Enum.find(spec.actions, &(&1.id == "calendly.webhooks.delete"))

    uri_field = Enum.find(action.input, &(&1.name == :uri))
    assert uri_field.required? == true
  end

  test "all webhook and cancel actions use personal_access_token auth" do
    spec = Calendly.integration()

    for id <- [
          "calendly.invitees.cancel",
          "calendly.webhooks.create",
          "calendly.webhooks.list",
          "calendly.webhooks.delete"
        ] do
      action = Enum.find(spec.actions, &(&1.id == id))
      assert action.auth_profile == :personal_access_token
    end
  end

  test "all webhook and cancel actions have scope resolver" do
    spec = Calendly.integration()

    for id <- [
          "calendly.invitees.cancel",
          "calendly.webhooks.create",
          "calendly.webhooks.list",
          "calendly.webhooks.delete"
        ] do
      action = Enum.find(spec.actions, &(&1.id == id))
      assert action.scope_resolver == Jido.Connect.Calendly.ScopeResolver
    end
  end
end
