defmodule Jido.Connect.Calendly.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly.{
    EventType,
    Invitee,
    Normalizer,
    Pagination,
    ScheduledEvent,
    WebhookSubscription
  }

  describe "event_type/1" do
    test "normalizes a wrapped resource response" do
      body = %{
        "resource" => %{
          "uri" => "https://api.calendly.com/event_types/i9j0k1l2",
          "name" => "30 Minute Meeting",
          "slug" => "30min",
          "duration" => 30,
          "active" => true
        }
      }

      assert {:ok, %EventType{} = et} = Normalizer.event_type(body)
      assert et.uri == "https://api.calendly.com/event_types/i9j0k1l2"
      assert et.name == "30 Minute Meeting"
      assert et.duration == 30
    end

    test "normalizes a bare resource map" do
      body = %{
        "uri" => "https://api.calendly.com/event_types/abc",
        "name" => "Test"
      }

      assert {:ok, %EventType{}} = Normalizer.event_type(body)
    end

    test "returns error for invalid body" do
      assert {:error, :invalid_event_type} = Normalizer.event_type(%{"foo" => "bar"})
    end
  end

  describe "event_type_list/1" do
    test "normalizes a paginated list response" do
      body = %{
        "collection" => [
          %{
            "uri" => "https://api.calendly.com/event_types/et1",
            "name" => "Meeting 1",
            "duration" => 30,
            "active" => true
          },
          %{
            "uri" => "https://api.calendly.com/event_types/et2",
            "name" => "Meeting 2",
            "duration" => 60,
            "active" => true
          }
        ],
        "pagination" => %{
          "previous" => nil,
          "next" => "https://api.calendly.com/event_types?page_token=abc",
          "count" => 2
        }
      }

      assert {:ok, %{items: items, pagination: %Pagination{} = page}} =
               Normalizer.event_type_list(body)

      assert length(items) == 2
      assert %EventType{} = hd(items)
      assert page.next_page == "https://api.calendly.com/event_types?page_token=abc"
      assert page.count == 2
    end

    test "returns error for invalid body" do
      assert {:error, :invalid_event_type_list} = Normalizer.event_type_list(%{"foo" => "bar"})
    end
  end

  describe "scheduled_event/1" do
    test "normalizes a wrapped resource response" do
      body = %{
        "resource" => %{
          "uri" => "https://api.calendly.com/scheduled_events/m3n4o5p6",
          "name" => "30 Minute Meeting",
          "status" => "active",
          "start_time" => "2026-05-20T10:00:00.000000Z",
          "end_time" => "2026-05-20T10:30:00.000000Z"
        }
      }

      assert {:ok, %ScheduledEvent{} = event} = Normalizer.scheduled_event(body)
      assert event.uri == "https://api.calendly.com/scheduled_events/m3n4o5p6"
      assert event.status == "active"
    end

    test "returns error for invalid body" do
      assert {:error, :invalid_scheduled_event} = Normalizer.scheduled_event(%{"x" => 1})
    end
  end

  describe "scheduled_event_list/1" do
    test "normalizes a paginated list response" do
      body = %{
        "collection" => [
          %{
            "uri" => "https://api.calendly.com/scheduled_events/ev1",
            "name" => "Event 1",
            "status" => "active"
          }
        ],
        "pagination" => %{
          "previous" => nil,
          "next" => nil,
          "count" => 1
        }
      }

      assert {:ok, %{items: items, pagination: %Pagination{} = page}} =
               Normalizer.scheduled_event_list(body)

      assert length(items) == 1
      assert %ScheduledEvent{} = hd(items)
      assert page.count == 1
    end

    test "returns error for invalid body" do
      assert {:error, :invalid_scheduled_event_list} =
               Normalizer.scheduled_event_list(%{"foo" => "bar"})
    end
  end

  describe "invitee/1" do
    test "normalizes a wrapped resource response" do
      body = %{
        "resource" => %{
          "uri" => "https://api.calendly.com/scheduled_events/ev1/invitees/inv1",
          "email" => "bob@example.com",
          "name" => "Bob Guest",
          "status" => "active"
        }
      }

      assert {:ok, %Invitee{} = invitee} = Normalizer.invitee(body)
      assert invitee.email == "bob@example.com"
      assert invitee.name == "Bob Guest"
    end

    test "returns error for invalid body" do
      assert {:error, :invalid_invitee} = Normalizer.invitee(%{"x" => 1})
    end
  end

  describe "invitee_list/1" do
    test "normalizes a paginated list response" do
      body = %{
        "collection" => [
          %{
            "uri" => "https://api.calendly.com/scheduled_events/ev1/invitees/inv1",
            "email" => "bob@example.com",
            "status" => "active"
          }
        ],
        "pagination" => %{
          "previous" => nil,
          "next" => nil,
          "count" => 1
        }
      }

      assert {:ok, %{items: items, pagination: %Pagination{} = page}} =
               Normalizer.invitee_list(body)

      assert length(items) == 1
      assert %Invitee{} = hd(items)
      assert page.count == 1
    end

    test "returns error for invalid body" do
      assert {:error, :invalid_invitee_list} = Normalizer.invitee_list(%{"foo" => "bar"})
    end
  end

  describe "webhook_subscription/1" do
    test "normalizes a wrapped resource response" do
      body = %{
        "resource" => %{
          "uri" => "https://api.calendly.com/webhook_subscriptions/wh1",
          "callback_url" => "https://example.com/webhook",
          "scope" => "organization",
          "organization" => "https://api.calendly.com/organizations/org1",
          "events" => ["invitee.created", "invitee.canceled"],
          "state" => "active"
        }
      }

      assert {:ok, %WebhookSubscription{} = webhook} = Normalizer.webhook_subscription(body)
      assert webhook.uri == "https://api.calendly.com/webhook_subscriptions/wh1"
      assert webhook.callback_url == "https://example.com/webhook"
      assert webhook.scope == "organization"
      assert webhook.events == ["invitee.created", "invitee.canceled"]
      assert webhook.state == "active"
    end

    test "normalizes a bare resource map" do
      body = %{"uri" => "https://api.calendly.com/webhook_subscriptions/wh1"}

      assert {:ok, %WebhookSubscription{}} = Normalizer.webhook_subscription(body)
    end

    test "returns error for invalid body" do
      assert {:error, :invalid_webhook_subscription} =
               Normalizer.webhook_subscription(%{"foo" => "bar"})
    end
  end

  describe "webhook_subscription_list/1" do
    test "normalizes a paginated list response" do
      body = %{
        "collection" => [
          %{
            "uri" => "https://api.calendly.com/webhook_subscriptions/wh1",
            "callback_url" => "https://example.com/webhook1",
            "events" => ["invitee.created"],
            "state" => "active"
          },
          %{
            "uri" => "https://api.calendly.com/webhook_subscriptions/wh2",
            "callback_url" => "https://example.com/webhook2",
            "events" => ["invitee.canceled"],
            "state" => "active"
          }
        ],
        "pagination" => %{
          "previous" => nil,
          "next" => "https://api.calendly.com/webhook_subscriptions?page_token=abc",
          "count" => 2
        }
      }

      assert {:ok, %{items: items, pagination: %Pagination{} = page}} =
               Normalizer.webhook_subscription_list(body)

      assert length(items) == 2
      assert %WebhookSubscription{} = hd(items)
      assert page.next_page == "https://api.calendly.com/webhook_subscriptions?page_token=abc"
      assert page.count == 2
    end

    test "returns error for invalid body" do
      assert {:error, :invalid_webhook_subscription_list} =
               Normalizer.webhook_subscription_list(%{"foo" => "bar"})
    end
  end
end
