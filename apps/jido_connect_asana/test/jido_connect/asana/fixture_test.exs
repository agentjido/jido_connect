defmodule Jido.Connect.Asana.FixtureTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.{Normalizer, Webhook}

  describe "workspace fixtures" do
    test "normalizes common workspace fixture" do
      payload = fixture!("workspace_common.json")

      assert {:ok, ws} = Normalizer.workspace(payload)
      assert ws.gid == "112233"
      assert ws.name == "Acme Corp"
      assert ws.is_organization == true
      assert "acme.example.com" in ws.email_domains
    end
  end

  describe "project fixtures" do
    test "normalizes common project fixture" do
      payload = fixture!("project_common.json")

      assert {:ok, proj} = Normalizer.project(payload)
      assert proj.gid == "445566"
      assert proj.name == "Website Redesign"
      assert proj.color == "dark-green"
      assert proj.archived == false
      assert proj.public == true
      assert proj.due_on == "2026-09-30"
      assert proj.start_on == "2026-06-01"
      assert proj.workspace_gid == "112233"
      assert proj.team_gid == "778899"
      assert proj.owner_gid == "123456"
    end
  end

  describe "task fixtures" do
    test "normalizes common task fixture" do
      payload = fixture!("task_common.json")

      assert {:ok, task} = Normalizer.task(payload)
      assert task.gid == "998877"
      assert task.name == "Design new landing page"
      assert task.assignee_gid == "123456"
      assert task.assignee_name == "Alice Nakamura"
      assert task.completed == false
      assert task.due_on == "2026-07-15"
      assert "445566" in task.project_gids
      assert "556677" in task.tag_gids
      assert task.section_gid == "889900"
    end
  end

  describe "section fixtures" do
    test "normalizes common section fixture" do
      payload = fixture!("section_common.json")

      assert {:ok, sec} = Normalizer.section(payload)
      assert sec.gid == "889900"
      assert sec.name == "In Progress"
      assert sec.project_gid == "445566"
    end
  end

  describe "user fixtures" do
    test "normalizes common user fixture" do
      payload = fixture!("user_common.json")

      assert {:ok, user} = Normalizer.user(payload)
      assert user.gid == "123456"
      assert user.name == "Alice Nakamura"
      assert user.email == "alice@example.com"
      assert user.photo != nil
    end
  end

  describe "story fixtures" do
    test "normalizes common story fixture" do
      payload = fixture!("story_common.json")

      assert {:ok, story} = Normalizer.story(payload)
      assert story.gid == "334455"
      assert story.resource_subtype == "comment_added"
      assert story.text =~ "Updated the wireframes"
      assert story.num_likes == 2
      assert story.target_gid == "998877"
      assert story.task_gid == "998877"
    end
  end

  describe "tag fixtures" do
    test "normalizes common tag fixture" do
      payload = fixture!("tag_common.json")

      assert {:ok, tag} = Normalizer.tag(payload)
      assert tag.gid == "556677"
      assert tag.name == "design"
      assert tag.color == "light-green"
      assert tag.workspace_gid == "112233"
    end
  end

  describe "custom field fixtures" do
    test "normalizes common custom field fixture" do
      payload = fixture!("custom_field_common.json")

      assert {:ok, cf} = Normalizer.custom_field(payload)
      assert cf.gid == "667788"
      assert cf.name == "Priority"
      assert cf.type == "enum"
      assert cf.enabled == true
      assert length(cf.enum_options) == 3
      assert cf.workspace_gid == "112233"
    end
  end

  describe "pagination fixtures" do
    test "normalizes common pagination fixture" do
      payload = fixture!("pagination_common.json")

      assert {:ok, page} = Normalizer.pagination(payload)
      assert page.offset == "eyJiIjoiIEP"
      assert page.has_next == true
    end
  end

  describe "webhook event fixtures" do
    test "normalizes task changed webhook fixture" do
      payload = fixture!("webhook_task_changed.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.resource_gid == "998877"
      assert signal.resource_type == "task"
      assert signal.change_type == "updated"
      assert signal.parent_gid == "445566"
      assert signal.user_gid == "123456"
    end

    test "normalizes task created webhook fixture" do
      payload = fixture!("webhook_task_created.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.resource_gid == "998899"
      assert signal.change_type == "created"
    end

    test "normalizes task deleted webhook fixture" do
      payload = fixture!("webhook_task_deleted.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.change_type == "deleted"
    end

    test "normalizes project changed webhook fixture" do
      payload = fixture!("webhook_project_changed.json")

      assert {:ok, signal} = Webhook.normalize_event(payload)
      assert signal.resource_gid == "445566"
      assert signal.resource_type == "project"
      assert signal.change_type == "updated"
    end

    test "normalizes batch webhook events fixture" do
      events = fixture!("webhook_batch_events.json")

      assert {:ok, signals} = Webhook.normalize_events(events)
      assert length(signals) == 2
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "test", "fixtures", "asana", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
