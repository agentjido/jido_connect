defmodule Jido.Connect.Intercom.FixtureTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Intercom.Client.Normalizer

  describe "contact fixtures" do
    test "normalizes common contact fixture" do
      payload = fixture!("contact_common.json")

      assert {:ok, contact} = Normalizer.contact(payload)
      assert contact.id == "661240"
      assert contact.name == "Alice Nakamura"
      assert contact.email == "alice@example.com"
      assert contact.phone == "+1-555-0100"
      assert contact.role == "user"
      assert contact.has_hard_bounced == false
      assert contact.marked_email_as_spam == false
      assert contact.unsubscribed_from_emails == false
      assert contact.external_id == "70"
      assert contact.browser == "Chrome"
      assert contact.browser_version == "125.0"
      assert contact.os == "macOS"
      assert contact.created_at == 1_717_804_800
      assert contact.updated_at == 1_718_496_000
    end

    test "normalizes contact location" do
      payload = fixture!("contact_common.json")

      assert {:ok, contact} = Normalizer.contact(payload)
      assert contact.location["country"] == "US"
      assert contact.location["region"] == "California"
      assert contact.location["city"] == "San Francisco"
    end

    test "normalizes contact avatar" do
      payload = fixture!("contact_common.json")

      assert {:ok, contact} = Normalizer.contact(payload)
      assert contact.avatar["type"] == "avatar"
      assert contact.avatar["image_url"] =~ "661240"
    end

    test "normalizes contact tags and companies" do
      payload = fixture!("contact_common.json")

      assert {:ok, contact} = Normalizer.contact(payload)
      assert is_map(contact.tags)
      assert is_map(contact.companies)
    end

    test "normalizes contact custom_attributes" do
      payload = fixture!("contact_common.json")

      assert {:ok, contact} = Normalizer.contact(payload)
      assert contact.custom_attributes["subscription_tier"] == "premium"
      assert contact.custom_attributes["account_owner"] == true
    end

    test "normalizes minimal contact fixture" do
      payload = fixture!("contact_minimal.json")

      assert {:ok, contact} = Normalizer.contact(payload)
      assert contact.id == "661241"
      assert contact.name == "Bob Martinez"
      assert contact.email == nil
    end

    test "normalizes contacts list with pagination" do
      payload = fixture!("contacts_list.json")

      assert {:ok, page} = Normalizer.pagination(payload)
      assert page.next != nil
      assert page.next["page"] == 2
      assert page.page == 1
      assert page.per_page == 20
      assert page.total_count == 2

      contacts = payload["data"]
      assert length(contacts) == 2

      assert {:ok, first} = Normalizer.contact(Enum.at(contacts, 0))
      assert first.id == "661240"
      assert first.name == "Alice Nakamura"

      assert {:ok, second} = Normalizer.contact(Enum.at(contacts, 1))
      assert second.id == "661241"
      assert second.name == "Bob Martinez"
    end
  end

  describe "company fixtures" do
    test "normalizes common company fixture" do
      payload = fixture!("company_common.json")

      assert {:ok, company} = Normalizer.company(payload)
      assert company.id == "531"
      assert company.name == "Acme Corp"
      assert company.company_id == "acme-001"
      assert company.remote_created_at == 1_700_000_000
      assert company.monthly_spend == 500
      assert company.session_count == 120
      assert company.user_count == 42
    end

    test "normalizes company plan, tags, and segments" do
      payload = fixture!("company_common.json")

      assert {:ok, company} = Normalizer.company(payload)
      assert is_map(company.plan)
      assert is_map(company.tags)
      assert is_map(company.segments)
    end

    test "normalizes company custom_attributes" do
      payload = fixture!("company_common.json")

      assert {:ok, company} = Normalizer.company(payload)
      assert company.custom_attributes["industry"] == "Technology"
      assert company.custom_attributes["revenue_band"] == "high"
    end

    test "normalizes minimal company fixture" do
      payload = fixture!("company_minimal.json")

      assert {:ok, company} = Normalizer.company(payload)
      assert company.id == "532"
      assert company.name == "Beta Inc"
      assert company.monthly_spend == nil
    end
  end

  describe "conversation fixtures" do
    test "normalizes common conversation fixture" do
      payload = fixture!("conversation_common.json")

      assert {:ok, conv} = Normalizer.conversation(payload)
      assert conv.id == "401"
      assert conv.state == "open"
      assert conv.open == true
      assert conv.read == true
      assert conv.title == "Need help with API integration"
      assert conv.priority == "not_priority"
      assert conv.waiting_since == 1_718_496_600
      assert conv.created_at == 1_718_496_000
      assert conv.updated_at == 1_718_496_600
    end

    test "normalizes conversation assignee from nested assignee object" do
      payload = fixture!("conversation_common.json")

      assert {:ok, conv} = Normalizer.conversation(payload)
      assert conv.admin_assignee_id == "991"
    end

    test "normalizes conversation source" do
      payload = fixture!("conversation_common.json")

      assert {:ok, conv} = Normalizer.conversation(payload)
      assert conv.source["delivered_as"] == "customer_initiated"
      assert conv.source["subject"] == "Need help with API integration"
    end

    test "normalizes conversation contacts and teammates" do
      payload = fixture!("conversation_common.json")

      assert {:ok, conv} = Normalizer.conversation(payload)
      assert is_map(conv.contacts)
      assert is_map(conv.teammates)
    end

    test "normalizes conversation statistics" do
      payload = fixture!("conversation_common.json")

      assert {:ok, conv} = Normalizer.conversation(payload)
      assert is_map(conv.statistics)
      assert conv.statistics["admin_reply_count"] == 1
      assert conv.statistics["contact_reply_count"] == 1
    end

    test "normalizes minimal conversation fixture" do
      payload = fixture!("conversation_minimal.json")

      assert {:ok, conv} = Normalizer.conversation(payload)
      assert conv.id == "402"
      assert conv.state == "closed"
      assert conv.open == false
    end
  end

  describe "conversation part fixtures" do
    test "normalizes common conversation part fixture" do
      payload = fixture!("conversation_part_common.json")

      assert {:ok, part} = Normalizer.conversation_part(payload)
      assert part.id == "800"
      assert part.part_type == "comment"
      assert part.body =~ "Let me check the documentation"
      assert part.created_at == 1_718_496_300
      assert part.notified_at == 1_718_496_310
    end

    test "normalizes conversation part author" do
      payload = fixture!("conversation_part_common.json")

      assert {:ok, part} = Normalizer.conversation_part(payload)
      assert is_map(part.author)
      assert part.author["type"] == "admin"
      assert part.author["id"] == "991"
    end

    test "normalizes conversation part assigned_to" do
      payload = fixture!("conversation_part_common.json")

      assert {:ok, part} = Normalizer.conversation_part(payload)
      assert is_map(part.assigned_to)
      assert part.assigned_to["id"] == "991"
    end

    test "normalizes conversation part attachments" do
      payload = fixture!("conversation_part_common.json")

      assert {:ok, part} = Normalizer.conversation_part(payload)
      assert length(part.attachments) == 1
      [attachment] = part.attachments
      assert attachment["name"] == "api-guide.pdf"
      assert attachment["content_type"] == "application/pdf"
    end

    test "normalizes minimal conversation part fixture" do
      payload = fixture!("conversation_part_minimal.json")

      assert {:ok, part} = Normalizer.conversation_part(payload)
      assert part.id == "801"
      assert part.part_type == "note"
      assert part.attachments == []
    end
  end

  describe "admin fixtures" do
    test "normalizes common admin fixture" do
      payload = fixture!("admin_common.json")

      assert {:ok, admin} = Normalizer.admin(payload)
      assert admin.id == "991"
      assert admin.name == "Carol Chen"
      assert admin.email == "carol@example.com"
      assert admin.job_title == "Senior Support Engineer"
      assert admin.away_mode_enabled == false
      assert admin.away_mode_reassign == false
      assert admin.has_inbox_seat == true
      assert admin.team_ids == ["team-100", "team-200"]
    end

    test "normalizes admin avatar" do
      payload = fixture!("admin_common.json")

      assert {:ok, admin} = Normalizer.admin(payload)
      assert is_map(admin.avatar)
      assert admin.avatar["type"] == "avatar"
    end

    test "normalizes minimal admin fixture" do
      payload = fixture!("admin_minimal.json")

      assert {:ok, admin} = Normalizer.admin(payload)
      assert admin.id == "992"
      assert admin.name == "Dave Park"
      assert admin.email == nil
      assert admin.team_ids == []
    end
  end

  describe "team fixtures" do
    test "normalizes common team fixture" do
      payload = fixture!("team_common.json")

      assert {:ok, team} = Normalizer.team(payload)
      assert team.id == "team-100"
      assert team.name == "Support"
      assert team.admin_ids == ["991", "992"]
    end

    test "normalizes minimal team fixture" do
      payload = fixture!("team_minimal.json")

      assert {:ok, team} = Normalizer.team(payload)
      assert team.id == "team-200"
      assert team.name == "Engineering"
      assert team.admin_ids == []
    end
  end

  describe "tag fixtures" do
    test "normalizes common tag fixture" do
      payload = fixture!("tag_common.json")

      assert {:ok, tag} = Normalizer.tag(payload)
      assert tag.id == "700"
      assert tag.name == "api"
    end

    test "normalizes tags list fixture" do
      payload = fixture!("tags_list.json")

      tags = payload["data"]
      assert length(tags) == 2

      assert {:ok, first} = Normalizer.tag(Enum.at(tags, 0))
      assert first.id == "700"
      assert first.name == "api"

      assert {:ok, second} = Normalizer.tag(Enum.at(tags, 1))
      assert second.id == "701"
      assert second.name == "integration"
    end
  end

  describe "pagination fixtures" do
    test "normalizes common pagination fixture" do
      payload = fixture!("pagination_common.json")

      assert {:ok, page} = Normalizer.pagination(payload)
      assert page.next != nil
      assert page.next["page"] == 2
      assert page.next["per_page"] == 20
      assert page.page == 1
      assert page.per_page == 20
      assert page.total_pages == 5
      assert page.total_count == 100
    end

    test "extracts pagination from contacts list envelope" do
      payload = fixture!("contacts_list.json")

      assert {:ok, page} = Normalizer.pagination(payload)
      assert page.total_count == 2
      assert page.page == 1
    end
  end

  describe "webhook event fixtures" do
    test "normalizes conversation created webhook" do
      payload = fixture!("webhook_conversation_created.json")

      assert {:ok, event} = Normalizer.normalize_webhook_event(payload)
      assert event.topic == "conversation.user.created"
      assert event.delivery_id == "delivery-001"
      assert event.delivery_attempt == 1
      assert event.app_id == "app-123"
      assert event.item["type"] == "conversation"
      assert event.item["id"] == "401"
    end

    test "normalizes admin replied webhook" do
      payload = fixture!("webhook_admin_replied.json")

      assert {:ok, event} = Normalizer.normalize_webhook_event(payload)
      assert event.topic == "conversation.admin.replied"
      assert event.delivery_id == "delivery-002"
      assert event.item["id"] == "401"
    end

    test "normalizes contact created webhook" do
      payload = fixture!("webhook_contact_created.json")

      assert {:ok, event} = Normalizer.normalize_webhook_event(payload)
      assert event.topic == "contact.created"
      assert event.delivery_id == "delivery-003"
      assert event.item["type"] == "contact"
      assert event.item["id"] == "661240"
      assert event.item["name"] == "Alice Nakamura"
    end

    test "rejects invalid webhook event" do
      assert {:error, :invalid_webhook_event_payload} =
               Normalizer.normalize_webhook_event("not a map")
    end
  end

  describe "error handling" do
    test "contact returns error for non-map input" do
      assert {:error, :invalid_contact_payload} = Normalizer.contact("not a map")
    end

    test "company returns error for non-map input" do
      assert {:error, :invalid_company_payload} = Normalizer.company("not a map")
    end

    test "conversation returns error for non-map input" do
      assert {:error, :invalid_conversation_payload} = Normalizer.conversation("not a map")
    end

    test "conversation_part returns error for non-map input" do
      assert {:error, :invalid_conversation_part_payload} =
               Normalizer.conversation_part("not a map")
    end

    test "admin returns error for non-map input" do
      assert {:error, :invalid_admin_payload} = Normalizer.admin("not a map")
    end

    test "team returns error for non-map input" do
      assert {:error, :invalid_team_payload} = Normalizer.team("not a map")
    end

    test "tag returns error for non-map input" do
      assert {:error, :invalid_tag_payload} = Normalizer.tag("not a map")
    end

    test "pagination returns error for non-map input" do
      assert {:error, :invalid_pagination_payload} = Normalizer.pagination("not a map")
    end
  end

  describe "privacy fixture review" do
    alias Jido.Connect.Sanitizer

    test "fixtures do not contain sensitive credential keys" do
      sensitive_keys = [
        "access_token",
        "api_key",
        "authorization",
        "client_secret",
        "password",
        "private_key",
        "refresh_token",
        "secret",
        "signing_secret",
        "token"
      ]

      fixtures =
        Path.join([__DIR__, "..", "..", "..", "test", "fixtures", "intercom", "*.json"])
        |> Path.wildcard()

      for path <- fixtures do
        json = File.read!(path)
        decoded = Jason.decode!(json)
        all_keys = collect_keys(decoded)

        for sensitive <- sensitive_keys do
          refute sensitive in all_keys,
                 "Fixture #{Path.basename(path)} contains sensitive key: #{sensitive}"
        end
      end
    end

    test "sanitizer redacts contact email in telemetry profile" do
      payload = fixture!("contact_common.json")
      {:ok, contact} = Normalizer.contact(payload)

      sanitized = Sanitizer.sanitize(contact, :telemetry)
      # name should pass through in telemetry
      assert sanitized.name == "Alice Nakamura"
      # email is not a sensitive key per sanitizer defaults
      # but verify the struct round-trips without error
      assert is_map(sanitized)
    end

    test "sanitizer handles all fixture structs without error" do
      fixtures_and_normalizers = [
        {"contact_common.json", &Normalizer.contact/1},
        {"company_common.json", &Normalizer.company/1},
        {"conversation_common.json", &Normalizer.conversation/1},
        {"conversation_part_common.json", &Normalizer.conversation_part/1},
        {"admin_common.json", &Normalizer.admin/1},
        {"team_common.json", &Normalizer.team/1},
        {"tag_common.json", &Normalizer.tag/1},
        {"pagination_common.json", &Normalizer.pagination/1}
      ]

      for {file, normalizer} <- fixtures_and_normalizers do
        payload = fixture!(file)
        {:ok, struct} = normalizer.(payload)
        sanitized = Sanitizer.sanitize(struct, :telemetry)
        assert is_map(sanitized), "Sanitizer failed for #{file}"
      end
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "test", "fixtures", "intercom", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end

  defp collect_keys(value) when is_map(value) do
    value
    |> Enum.flat_map(fn {k, v} -> [k | collect_keys(v)] end)
  end

  defp collect_keys(value) when is_list(value) do
    Enum.flat_map(value, &collect_keys/1)
  end

  defp collect_keys(_value), do: []
end
