defmodule Jido.Connect.Calendly.FixtureTest do
  @moduledoc """
  Validates that representative Calendly JSON fixtures parse cleanly
  through the normalized Zoi structs.
  """
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly.{
    Cancellation,
    EventType,
    Invitee,
    Organization,
    Pagination,
    ScheduledEvent,
    User,
    WebhookSubscription
  }

  test "user fixture parses into User struct" do
    payload = fixture!("user.json")

    assert {:ok, user} =
             User.new(%{
               uri: payload["uri"],
               email: payload["email"],
               name: payload["name"],
               scheduling_url: payload["scheduling_url"],
               slug: payload["slug"],
               timezone: payload["timezone"],
               avatar_url: payload["avatar_url"],
               organization_uri: payload["current_organization"],
               created_at: payload["created_at"],
               updated_at: payload["updated_at"]
             })

    assert %User{} = user
    assert user.uri == "https://api.calendly.com/users/a1b2c3d4"
    assert user.email == "alice@example.com"
    assert user.name == "Alice Example"
    assert user.timezone == "America/Chicago"
    assert user.organization_uri == "https://api.calendly.com/organizations/e5f6g7h8"
  end

  test "organization fixture parses into Organization struct" do
    payload = fixture!("organization.json")

    assert {:ok, org} =
             Organization.new(%{
               uri: payload["uri"],
               name: payload["name"],
               slug: payload["slug"],
               invite_url: payload["invite_url"],
               scheduling_url: payload["scheduling_url"],
               owner_uri: payload["owner"],
               created_at: payload["created_at"],
               updated_at: payload["updated_at"]
             })

    assert %Organization{} = org
    assert org.uri == "https://api.calendly.com/organizations/e5f6g7h8"
    assert org.name == "Example Corp"
    assert org.slug == "example-corp"
    assert org.owner_uri == "https://api.calendly.com/users/a1b2c3d4"
  end

  test "event type fixture parses into EventType struct" do
    payload = fixture!("event_type.json")

    assert {:ok, event_type} =
             EventType.new(%{
               uri: payload["uri"],
               name: payload["name"],
               slug: payload["slug"],
               description: payload["description"],
               duration: payload["duration"],
               active: payload["active"],
               kind: payload["kind"],
               scheduling_url: payload["scheduling_url"],
               owner_uri: payload["owner"],
               owner_type: payload["owner_type"],
               location: payload["location"],
               color: payload["color"],
               pooling_type: payload["pooling_type"],
               secret: payload["secret"],
               created_at: payload["created_at"],
               updated_at: payload["updated_at"]
             })

    assert %EventType{} = event_type
    assert event_type.uri == "https://api.calendly.com/event_types/i9j0k1l2"
    assert event_type.name == "30 Minute Meeting"
    assert event_type.duration == 30
    assert event_type.active == true
    assert event_type.secret == false
  end

  test "scheduled event fixture parses into ScheduledEvent struct" do
    payload = fixture!("scheduled_event.json")

    assert {:ok, event} =
             ScheduledEvent.new(%{
               uri: payload["uri"],
               name: payload["name"],
               status: payload["status"],
               start_time: payload["start_time"],
               end_time: payload["end_time"],
               location: payload["location"],
               event_type_uri: payload["event_type"],
               event_type_name: payload["event_type_name"],
               organization_uri: payload["organization"],
               cancellation: payload["cancellation"],
               invitees_counter: payload["invitees_counter"],
               created_at: payload["created_at"],
               updated_at: payload["updated_at"]
             })

    assert %ScheduledEvent{} = event
    assert event.uri == "https://api.calendly.com/scheduled_events/m3n4o5p6"
    assert event.status == "active"
    assert event.start_time == "2026-05-20T10:00:00.000000Z"
    assert event.end_time == "2026-05-20T10:30:00.000000Z"
    assert event.invitees_counter == %{"total" => 1, "active" => 1, "limit" => 1}
    assert event.cancellation == nil
    assert event.invitees == []
  end

  test "invitee fixture parses into Invitee struct" do
    payload = fixture!("invitee.json")

    assert {:ok, invitee} =
             Invitee.new(%{
               uri: payload["uri"],
               email: payload["email"],
               name: payload["name"],
               status: payload["status"],
               timezone: payload["timezone"],
               event_uri: payload["event"],
               new_invitee_uri: payload["new_invitee"],
               old_invitee_uri: payload["old_invitee"],
               canceled_by: payload["canceled_by"],
               cancellation_reason: payload["cancellation_reason"],
               reschedule_reason: payload["reschedule_reason"],
               reschedule_url: payload["reschedule_url"],
               cancel_url: payload["cancel_url"],
               questions_and_answers: payload["questions_and_answers"],
               created_at: payload["created_at"],
               updated_at: payload["updated_at"]
             })

    assert %Invitee{} = invitee
    assert invitee.uri == "https://api.calendly.com/scheduled_events/m3n4o5p6/invitees/q7r8s9t0"
    assert invitee.email == "bob@example.com"
    assert invitee.name == "Bob Guest"
    assert invitee.status == "active"
    assert length(invitee.questions_and_answers) == 1
  end

  test "cancellation fixture parses into Cancellation struct" do
    payload = fixture!("cancellation.json")

    assert {:ok, cancellation} =
             Cancellation.new(%{
               canceled_by: payload["canceled_by"],
               reason: payload["reason"],
               invitee_uri: payload["invitee"],
               event_uri: payload["event"],
               organization_uri: payload["organization"],
               canceled_at: payload["canceled_at"]
             })

    assert %Cancellation{} = cancellation
    assert cancellation.canceled_by == "alice@example.com"
    assert cancellation.reason == "Schedule conflict"
    assert cancellation.canceled_at == "2026-05-19T12:00:00.000000Z"
  end

  test "webhook subscription fixture parses into WebhookSubscription struct" do
    payload = fixture!("webhook_subscription.json")

    assert {:ok, webhook} =
             WebhookSubscription.new(%{
               uri: payload["uri"],
               callback_url: payload["callback_url"],
               scope: payload["scope"],
               organization_uri: payload["organization"],
               user_uri: payload["user"],
               events: payload["events"],
               state: payload["state"],
               created_at: payload["created_at"],
               updated_at: payload["updated_at"]
             })

    assert %WebhookSubscription{} = webhook
    assert webhook.uri == "https://api.calendly.com/webhook_subscriptions/u1v2w3x4"
    assert webhook.callback_url == "https://example.com/calendly/webhook"
    assert webhook.scope == "organization"
    assert "invitee.created" in webhook.events
    assert "invitee.canceled" in webhook.events
    assert webhook.state == "active"
  end

  test "paginated events fixture parses into Pagination struct" do
    payload = fixture!("paginated_events.json")

    assert {:ok, pagination} =
             Pagination.new(%{
               items: payload["collection"],
               previous_page: payload["pagination"]["previous"],
               next_page: payload["pagination"]["next"],
               count: payload["pagination"]["count"]
             })

    assert %Pagination{} = pagination
    assert length(pagination.items) == 2
    assert pagination.next_page =~ "page_token=next_page_token"
    assert pagination.previous_page == nil
    assert pagination.count == 2
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "fixtures", "calendly", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
