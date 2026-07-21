defmodule Jido.Connect.Zendesk.FixtureTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Zendesk.Client.Normalizer

  describe "ticket fixtures" do
    test "normalizes common ticket fixture" do
      payload = fixture!("ticket_common.json")

      assert {:ok, ticket} = Normalizer.ticket(payload)
      assert ticket.id == 12345
      assert ticket.subject == "Cannot reset password"
      assert ticket.description =~ "resetting my password"
      assert ticket.status == "open"
      assert ticket.type == "incident"
      assert ticket.priority == "normal"
      assert ticket.requester_id == 9901
      assert ticket.assignee_id == 9001
      assert ticket.group_id == 101
      assert ticket.organization_id == 201
      assert ticket.tags == ["password", "login", "urgent"]
      assert ticket.external_id == "EXT-98765"
      assert ticket.brand_id == 1
      assert ticket.form_id == 10
      assert ticket.created_at == "2026-03-15T10:30:00Z"
      assert ticket.updated_at == "2026-05-10T14:22:00Z"
    end

    test "normalizes ticket via and satisfaction_rating" do
      payload = fixture!("ticket_common.json")

      assert {:ok, ticket} = Normalizer.ticket(payload)
      assert ticket.via["channel"] == "web"
      assert ticket.satisfaction_rating["score"] == "unoffered"
    end

    test "normalizes ticket custom_fields" do
      payload = fixture!("ticket_common.json")

      assert {:ok, ticket} = Normalizer.ticket(payload)
      assert length(ticket.custom_fields) == 2
      assert Enum.at(ticket.custom_fields, 0)[:id] == 123
      assert Enum.at(ticket.custom_fields, 0)[:value] == "premium"
    end

    test "normalizes minimal ticket fixture" do
      payload = fixture!("ticket_minimal.json")

      assert {:ok, ticket} = Normalizer.ticket(payload)
      assert ticket.id == 12346
      assert ticket.subject == "Billing inquiry for enterprise plan"
      assert ticket.status == "pending"
      assert ticket.type == "question"
      assert ticket.priority == "high"
      assert ticket.assignee_id == nil
      assert ticket.tags == ["billing", "enterprise"]
      assert ticket.due_at == "2026-06-01T00:00:00Z"
      assert ticket.satisfaction_rating["score"] == "good"
    end

    test "normalizes tickets list fixture with pagination" do
      payload = fixture!("tickets_list.json")

      assert {:ok, page} = Normalizer.pagination(payload)
      assert page.has_more == true
      assert page.after_cursor != nil
      assert page.next_url =~ "page=2"

      tickets = payload["tickets"]
      assert length(tickets) == 2

      assert {:ok, first} = Normalizer.ticket(Enum.at(tickets, 0))
      assert first.id == 12345
      assert first.subject == "Cannot reset password"

      assert {:ok, second} = Normalizer.ticket(Enum.at(tickets, 1))
      assert second.id == 12346
      assert second.status == "pending"
      assert second.tags == ["billing", "enterprise"]
    end
  end

  describe "user fixtures" do
    test "normalizes common user fixture" do
      payload = fixture!("user_common.json")

      assert {:ok, user} = Normalizer.user(payload)
      assert user.id == 9001
      assert user.email == "alice@example.com"
      assert user.name == "Alice Nakamura"
      assert user.role == "agent"
      assert user.verified == true
      assert user.active == true
      assert user.time_zone == "Pacific Time (US & Canada)"
      assert user.locale == "en-US"
      assert user.organization_id == 201
      assert user.phone == "+1-555-0100"
      assert user.tags == ["support", "tier-1"]
      assert user.external_id == "ext-alice-001"
      assert user.details =~ "Senior support agent"
      assert user.notes =~ "Available weekdays"
      assert user.created_at == "2025-06-01T08:00:00Z"
      assert user.updated_at == "2026-05-01T12:00:00Z"
    end

    test "normalizes user photo" do
      payload = fixture!("user_common.json")

      assert {:ok, user} = Normalizer.user(payload)
      assert user.photo["content_type"] == "image/png"
      assert user.photo["size"] == 1024
    end

    test "normalizes minimal user fixture" do
      payload = fixture!("user_minimal.json")

      assert {:ok, user} = Normalizer.user(payload)
      assert user.id == 9901
      assert user.email == "bob@example.com"
      assert user.name == "Bob Martinez"
      assert user.role == "end-user"
      assert user.tags == []
    end
  end

  describe "organization fixtures" do
    test "normalizes common organization fixture" do
      payload = fixture!("organization_common.json")

      assert {:ok, org} = Normalizer.organization(payload)
      assert org.id == 201
      assert org.name == "Acme Corp"
      assert org.domain_names == ["acme.com", "acmecorp.com"]
      assert org.details =~ "Enterprise customer"
      assert org.notes =~ "VIP organization"
      assert org.group_id == 101
      assert org.tags == ["enterprise", "vip"]
      assert org.external_id == "ext-acme-201"
      assert org.shared_tickets == true
      assert org.shared_comments == false
      assert org.created_at == "2024-01-15T09:00:00Z"
      assert org.updated_at == "2026-03-20T14:30:00Z"
    end
  end

  describe "comment fixtures" do
    test "normalizes common comment fixture" do
      payload = fixture!("comment_common.json")

      assert {:ok, comment} = Normalizer.comment(payload)
      assert comment.id == 50001
      assert comment.body =~ "checked the email configuration"
      assert comment.html_body =~ "<p>"
      assert comment.plain_body =~ "checked the email configuration"
      assert comment.author_id == 9001
      assert comment.public == true
      assert comment.ticket_id == 12345
      assert comment.created_at == "2026-03-15T11:00:00Z"
    end

    test "normalizes comment via and metadata" do
      payload = fixture!("comment_common.json")

      assert {:ok, comment} = Normalizer.comment(payload)
      assert comment.via["channel"] == "web"
      assert is_map(comment.zendesk_metadata)
      assert comment.zendesk_metadata["system"]["client"] == "web"
    end

    test "normalizes comment attachments" do
      payload = fixture!("comment_common.json")

      assert {:ok, comment} = Normalizer.comment(payload)
      assert length(comment.attachments) == 1
      [attachment] = comment.attachments
      assert attachment["file_name"] == "screenshot.png"
      assert attachment["content_type"] == "image/png"
    end
  end

  describe "group fixtures" do
    test "normalizes common group fixture" do
      payload = fixture!("group_common.json")

      assert {:ok, group} = Normalizer.group(payload)
      assert group.id == 101
      assert group.name == "Support Team"
      assert group.description =~ "First-level customer support"
      assert group.default == true
      assert group.deleted == false
      assert group.created_at == "2025-01-01T00:00:00Z"
      assert group.updated_at == "2026-04-15T10:00:00Z"
    end
  end

  describe "pagination fixtures" do
    test "normalizes common pagination fixture" do
      payload = fixture!("pagination_common.json")

      assert {:ok, page} = Normalizer.pagination(payload)
      assert page.has_more == true
      assert page.after_cursor != nil
      assert page.next_url =~ "page=2"
      assert page.count == 100
    end
  end

  describe "tag normalization" do
    test "normalizes tag names into tag structs" do
      names = ["password", "login", "urgent"]

      results = Normalizer.tag_names(names)
      assert length(results) == 3

      assert {:ok, first} = Enum.at(results, 0)
      assert first.name == "password"

      assert {:ok, second} = Enum.at(results, 1)
      assert second.name == "login"

      assert {:ok, third} = Enum.at(results, 2)
      assert third.name == "urgent"
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "test", "fixtures", "zendesk", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
