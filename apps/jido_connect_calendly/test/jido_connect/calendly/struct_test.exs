defmodule Jido.Connect.Calendly.StructTest do
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

  describe "User" do
    test "validates with required and optional fields" do
      user =
        User.new!(%{
          uri: "https://api.calendly.com/users/a1b2c3d4",
          email: "alice@example.com",
          name: "Alice Example",
          scheduling_url: "https://calendly.com/alice-example",
          slug: "alice-example",
          timezone: "America/Chicago"
        })

      assert user.uri == "https://api.calendly.com/users/a1b2c3d4"
      assert user.email == "alice@example.com"
      assert user.name == "Alice Example"
      assert user.timezone == "America/Chicago"
      assert user.metadata == %{}
    end

    test "defaults optional fields" do
      user = User.new!(%{uri: "https://api.calendly.com/users/abc"})

      assert user.email == nil
      assert user.organization_uri == nil
      assert user.metadata == %{}
    end

    test "rejects missing required fields" do
      assert {:error, _error} = User.new(%{})
    end
  end

  describe "Organization" do
    test "validates with required and optional fields" do
      org =
        Organization.new!(%{
          uri: "https://api.calendly.com/organizations/e5f6g7h8",
          name: "Example Corp",
          slug: "example-corp",
          owner_uri: "https://api.calendly.com/users/a1b2c3d4"
        })

      assert org.uri == "https://api.calendly.com/organizations/e5f6g7h8"
      assert org.name == "Example Corp"
      assert org.slug == "example-corp"
      assert org.owner_uri == "https://api.calendly.com/users/a1b2c3d4"
      assert org.metadata == %{}
    end

    test "defaults optional fields" do
      org = Organization.new!(%{uri: "https://api.calendly.com/organizations/abc"})

      assert org.name == nil
      assert org.metadata == %{}
    end

    test "rejects missing required fields" do
      assert {:error, _error} = Organization.new(%{})
    end
  end

  describe "EventType" do
    test "validates with required and optional fields" do
      event_type =
        EventType.new!(%{
          uri: "https://api.calendly.com/event_types/i9j0k1l2",
          name: "30 Minute Meeting",
          slug: "30min",
          duration: 30,
          active: true,
          kind: "solo",
          scheduling_url: "https://calendly.com/alice-example/30min"
        })

      assert event_type.uri == "https://api.calendly.com/event_types/i9j0k1l2"
      assert event_type.name == "30 Minute Meeting"
      assert event_type.duration == 30
      assert event_type.active == true
      assert event_type.secret == false
      assert event_type.metadata == %{}
    end

    test "defaults boolean and collection fields" do
      event_type = EventType.new!(%{uri: "https://api.calendly.com/event_types/abc"})

      assert event_type.active == true
      assert event_type.secret == false
      assert event_type.metadata == %{}
    end

    test "rejects missing required fields" do
      assert {:error, _error} = EventType.new(%{})
    end
  end

  describe "ScheduledEvent" do
    test "validates with required and optional fields" do
      event =
        ScheduledEvent.new!(%{
          uri: "https://api.calendly.com/scheduled_events/m3n4o5p6",
          name: "30 Minute Meeting",
          status: "active",
          start_time: "2026-05-20T10:00:00.000000Z",
          end_time: "2026-05-20T10:30:00.000000Z",
          event_type_uri: "https://api.calendly.com/event_types/i9j0k1l2",
          invitees_counter: %{"total" => 1, "active" => 1, "limit" => 1}
        })

      assert event.uri == "https://api.calendly.com/scheduled_events/m3n4o5p6"
      assert event.status == "active"
      assert event.start_time == "2026-05-20T10:00:00.000000Z"
      assert event.invitees_counter == %{"total" => 1, "active" => 1, "limit" => 1}
      assert event.invitees == []
      assert event.cancellation == nil
      assert event.metadata == %{}
    end

    test "defaults collection fields" do
      event = ScheduledEvent.new!(%{uri: "https://api.calendly.com/scheduled_events/abc"})

      assert event.invitees == []
      assert event.invitees_counter == %{}
      assert event.metadata == %{}
    end

    test "rejects missing required fields" do
      assert {:error, _error} = ScheduledEvent.new(%{})
    end
  end

  describe "Invitee" do
    test "validates with required and optional fields" do
      invitee =
        Invitee.new!(%{
          uri: "https://api.calendly.com/scheduled_events/m3n4o5p6/invitees/q7r8s9t0",
          email: "bob@example.com",
          name: "Bob Guest",
          status: "active",
          timezone: "America/New_York"
        })

      assert invitee.uri == "https://api.calendly.com/scheduled_events/m3n4o5p6/invitees/q7r8s9t0"
      assert invitee.email == "bob@example.com"
      assert invitee.status == "active"
      assert invitee.questions_and_answers == []
      assert invitee.metadata == %{}
    end

    test "defaults collection fields" do
      invitee = Invitee.new!(%{uri: "https://api.calendly.com/scheduled_events/x/invitees/y"})

      assert invitee.questions_and_answers == []
      assert invitee.metadata == %{}
    end

    test "rejects missing required fields" do
      assert {:error, _error} = Invitee.new(%{})
    end
  end

  describe "Cancellation" do
    test "validates with all optional fields" do
      cancellation =
        Cancellation.new!(%{
          canceled_by: "alice@example.com",
          reason: "Schedule conflict",
          invitee_uri: "https://api.calendly.com/scheduled_events/m3n4o5p6/invitees/q7r8s9t0",
          canceled_at: "2026-05-19T12:00:00.000000Z"
        })

      assert cancellation.canceled_by == "alice@example.com"
      assert cancellation.reason == "Schedule conflict"
      assert cancellation.canceled_at == "2026-05-19T12:00:00.000000Z"
      assert cancellation.metadata == %{}
    end

    test "accepts empty map with defaults" do
      cancellation = Cancellation.new!(%{})

      assert cancellation.canceled_by == nil
      assert cancellation.reason == nil
      assert cancellation.metadata == %{}
    end
  end

  describe "WebhookSubscription" do
    test "validates with required and optional fields" do
      webhook =
        WebhookSubscription.new!(%{
          uri: "https://api.calendly.com/webhook_subscriptions/u1v2w3x4",
          callback_url: "https://example.com/calendly/webhook",
          scope: "organization",
          organization_uri: "https://api.calendly.com/organizations/e5f6g7h8",
          events: ["invitee.created", "invitee.canceled"],
          state: "active"
        })

      assert webhook.uri == "https://api.calendly.com/webhook_subscriptions/u1v2w3x4"
      assert webhook.callback_url == "https://example.com/calendly/webhook"
      assert webhook.scope == "organization"
      assert webhook.events == ["invitee.created", "invitee.canceled"]
      assert webhook.state == "active"
      assert webhook.metadata == %{}
    end

    test "defaults collection fields" do
      webhook =
        WebhookSubscription.new!(%{uri: "https://api.calendly.com/webhook_subscriptions/abc"})

      assert webhook.events == []
      assert webhook.metadata == %{}
    end

    test "rejects missing required fields" do
      assert {:error, _error} = WebhookSubscription.new(%{})
    end
  end

  describe "Pagination" do
    test "validates with paginated items" do
      pagination =
        Pagination.new!(%{
          items: [%{"uri" => "item1"}, %{"uri" => "item2"}],
          next_page: "https://api.calendly.com/events?page=2",
          count: 2
        })

      assert length(pagination.items) == 2
      assert pagination.next_page == "https://api.calendly.com/events?page=2"
      assert pagination.count == 2
      assert pagination.previous_page == nil
      assert pagination.metadata == %{}
    end

    test "defaults collection fields" do
      pagination = Pagination.new!(%{})

      assert pagination.items == []
      assert pagination.count == nil
      assert pagination.metadata == %{}
    end
  end
end
