defmodule Jido.Connect.Zendesk.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Zendesk.Client.Normalizer

  describe "ticket/1" do
    test "returns error for non-map payload" do
      assert Normalizer.ticket("not a map") == {:error, :invalid_ticket_payload}
      assert Normalizer.ticket(nil) == {:error, :invalid_ticket_payload}
    end

    test "normalizes ticket with minimal fields" do
      assert {:ok, ticket} = Normalizer.ticket(%{"id" => 42})
      assert ticket.id == 42
      assert ticket.tags == []
      assert ticket.custom_fields == []
      assert ticket.metadata == %{}
    end
  end

  describe "user/1" do
    test "returns error for non-map payload" do
      assert Normalizer.user("not a map") == {:error, :invalid_user_payload}
    end

    test "normalizes user with minimal fields" do
      assert {:ok, user} = Normalizer.user(%{"id" => 42})
      assert user.id == 42
      assert user.tags == []
      assert user.metadata == %{}
    end
  end

  describe "organization/1" do
    test "returns error for non-map payload" do
      assert Normalizer.organization("not a map") == {:error, :invalid_organization_payload}
    end

    test "normalizes organization with minimal fields" do
      assert {:ok, org} = Normalizer.organization(%{"id" => 42})
      assert org.id == 42
      assert org.domain_names == []
      assert org.tags == []
      assert org.metadata == %{}
    end
  end

  describe "comment/1" do
    test "returns error for non-map payload" do
      assert Normalizer.comment("not a map") == {:error, :invalid_comment_payload}
    end

    test "normalizes comment with minimal fields" do
      assert {:ok, comment} = Normalizer.comment(%{"id" => 42})
      assert comment.id == 42
      assert comment.attachments == []
      assert comment.metadata == %{}
    end
  end

  describe "tag/1" do
    test "returns error for non-map payload" do
      assert Normalizer.tag("not a map") == {:error, :invalid_tag_payload}
    end

    test "normalizes tag with name only" do
      assert {:ok, tag} = Normalizer.tag(%{"name" => "urgent"})
      assert tag.name == "urgent"
      assert tag.count == nil
    end

    test "normalizes tag with count" do
      assert {:ok, tag} = Normalizer.tag(%{"name" => "billing", "count" => 47})
      assert tag.name == "billing"
      assert tag.count == 47
    end
  end

  describe "group/1" do
    test "returns error for non-map payload" do
      assert Normalizer.group("not a map") == {:error, :invalid_group_payload}
    end

    test "normalizes group with minimal fields" do
      assert {:ok, group} = Normalizer.group(%{"id" => 42})
      assert group.id == 42
      assert group.metadata == %{}
    end
  end

  describe "pagination/1" do
    test "returns error for non-map payload" do
      assert Normalizer.pagination("not a map") == {:error, :invalid_pagination_payload}
    end

    test "normalizes cursor-based pagination" do
      payload = %{
        "meta" => %{
          "has_more" => true,
          "after_cursor" => "abc123",
          "before_cursor" => nil
        },
        "links" => %{
          "next" => "https://example.zendesk.com/api/v2/tickets.json?page=2",
          "prev" => nil
        }
      }

      assert {:ok, page} = Normalizer.pagination(payload)
      assert page.has_more == true
      assert page.after_cursor == "abc123"
      assert page.next_url =~ "page=2"
    end

    test "normalizes offset-based pagination" do
      payload = %{
        "next_page" => "https://example.zendesk.com/api/v2/tickets.json?page=3",
        "previous_page" => "https://example.zendesk.com/api/v2/tickets.json?page=1",
        "count" => 100
      }

      assert {:ok, page} = Normalizer.pagination(payload)
      assert page.next_page =~ "page=3"
      assert page.previous_page =~ "page=1"
      assert page.count == 100
    end

    test "normalizes empty pagination envelope" do
      assert {:ok, page} = Normalizer.pagination(%{})
      assert page.metadata == %{}
    end
  end
end
