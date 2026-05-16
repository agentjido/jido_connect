defmodule Jido.Connect.Jira.FixtureTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Jira.Client.Normalizer

  describe "issue fixtures" do
    test "normalizes common issue fixture" do
      payload = fixture!("issue_common.json")

      assert {:ok, issue} = Normalizer.issue(payload)
      assert issue.key == "PROJ-123"
      assert issue.id == "10001"
      assert issue.summary == "Implement user authentication flow"
      assert issue.description == "We need to add OAuth2 support for the login flow."
      assert issue.labels == ["backend", "auth"]
      assert issue.created_at == "2026-04-10T08:30:00.000+0000"
      assert issue.updated_at == "2026-05-15T14:22:00.000+0000"
      assert issue.due_date == "2026-06-15"
    end

    test "normalizes issue status" do
      payload = fixture!("issue_common.json")

      assert {:ok, issue} = Normalizer.issue(payload)
      assert issue.status.name == "In Progress"
      assert issue.status.id == "3"
      assert issue.status.category["name"] == "In Progress"
    end

    test "normalizes issue assignee and reporter" do
      payload = fixture!("issue_common.json")

      assert {:ok, issue} = Normalizer.issue(payload)
      assert issue.assignee.account_id == "5f8a7b9c1d2e3f4a5b6c7d8e"
      assert issue.assignee.display_name == "Alice Nakamura"
      assert issue.assignee.active == true
      assert issue.reporter.display_name == "Bob Martinez"
    end

    test "normalizes issue project, type, and priority" do
      payload = fixture!("issue_common.json")

      assert {:ok, issue} = Normalizer.issue(payload)
      assert issue.project[:key] == "PROJ"
      assert issue.project[:name] == "Project Alpha"
      assert issue.issue_type[:name] == "Task"
      assert issue.issue_type[:subtask] == false
      assert issue.priority[:name] == "Medium"
    end

    test "normalizes issue search results fixture" do
      payload = fixture!("issue_search_results.json")

      assert {:ok, page} = Normalizer.pagination(payload)
      assert page.start_at == 0
      assert page.max_results == 50
      assert page.total == 2
      assert page.is_last == true

      issues = payload["issues"]
      assert length(issues) == 2

      assert {:ok, first} = Normalizer.issue(Enum.at(issues, 0))
      assert first.key == "PROJ-123"

      assert {:ok, second} = Normalizer.issue(Enum.at(issues, 1))
      assert second.key == "PROJ-124"
      assert second.labels == ["frontend", "auth"]
    end
  end

  describe "project fixtures" do
    test "normalizes common project fixture" do
      payload = fixture!("project_common.json")

      assert {:ok, project} = Normalizer.project(payload)
      assert project.key == "PROJ"
      assert project.id == "10000"
      assert project.name == "Project Alpha"
      assert project.project_type == "software"
      assert project.style == "classic"
      assert project.description == "Main software project for the Alpha product line."
    end

    test "normalizes project lead as user" do
      payload = fixture!("project_common.json")

      assert {:ok, project} = Normalizer.project(payload)
      assert project.lead.account_id == "5f8a7b9c1d2e3f4a5b6c7d8e"
      assert project.lead.display_name == "Alice Nakamura"
    end

    test "normalizes project category" do
      payload = fixture!("project_common.json")

      assert {:ok, project} = Normalizer.project(payload)
      assert project.category["name"] == "Engineering"
    end
  end

  describe "user fixtures" do
    test "normalizes common user fixture" do
      payload = fixture!("user_common.json")

      assert {:ok, user} = Normalizer.user(payload)
      assert user.account_id == "5f8a7b9c1d2e3f4a5b6c7d8e"
      assert user.display_name == "Alice Nakamura"
      assert user.email == "alice@example.com"
      assert user.active == true
      assert user.time_zone == "America/Los_Angeles"
      assert user.locale == "en_US"
      assert user.account_type == "atlassian"
    end
  end

  describe "comment fixtures" do
    test "normalizes common comment fixture" do
      payload = fixture!("comment_common.json")

      assert {:ok, comment} = Normalizer.comment(payload)
      assert comment.id == "20010"
      assert comment.body == "Investigated the OAuth2 flow. Ready to start implementation."

      assert comment.rendered_body ==
               "<p>Investigated the OAuth2 flow. Ready to start implementation.</p>"

      assert comment.jsd_public == true
      assert comment.created_at == "2026-05-01T10:30:00.000+0000"
    end

    test "normalizes comment author" do
      payload = fixture!("comment_common.json")

      assert {:ok, comment} = Normalizer.comment(payload)
      assert comment.author.account_id == "5f8a7b9c1d2e3f4a5b6c7d8e"
      assert comment.author.display_name == "Alice Nakamura"
    end
  end

  describe "status fixtures" do
    test "normalizes common status fixture" do
      payload = fixture!("status_common.json")

      assert {:ok, status} = Normalizer.status(payload)
      assert status.id == "3"
      assert status.name == "In Progress"
      assert status.category["key"] == "indeterminate"
      assert status.category["colorName"] == "yellow"
      assert status.description == "This issue is being actively worked on."
    end
  end

  describe "transition fixtures" do
    test "normalizes common transition fixture" do
      payload = fixture!("transition_common.json")

      assert {:ok, transition} = Normalizer.transition(payload)
      assert transition.id == "21"
      assert transition.name == "Start Progress"
      assert transition.has_screen == true
      assert transition.is_global == false
      assert transition.is_initial == false
      assert transition.is_conditional == true
    end

    test "normalizes transition to_status" do
      payload = fixture!("transition_common.json")

      assert {:ok, transition} = Normalizer.transition(payload)
      assert transition.to_status.name == "In Progress"
      assert transition.to_status.id == "3"
      assert transition.to_status.category["key"] == "indeterminate"
    end

    test "normalizes transition fields" do
      payload = fixture!("transition_common.json")

      assert {:ok, transition} = Normalizer.transition(payload)
      assert is_map(transition.fields)
      assert Map.has_key?(transition.fields, "assignee")
      assert Map.has_key?(transition.fields, "resolution")
    end
  end

  describe "field schema fixtures" do
    test "normalizes common field schema fixture" do
      payload = fixture!("field_schema_common.json")

      assert {:ok, field} = Normalizer.field_schema(payload)
      assert field.id == "summary"
      assert field.name == "Summary"
      assert field.key == "summary"
      assert field.custom == false
      assert field.orderable == true
      assert field.navigable == true
      assert field.searchable == true
      assert field.clause_names == ["summary"]
      assert field.schema["type"] == "string"
      assert field.schema["system"] == "summary"
    end
  end

  describe "pagination fixtures" do
    test "normalizes common pagination fixture" do
      payload = fixture!("pagination_common.json")

      assert {:ok, page} = Normalizer.pagination(payload)
      assert page.start_at == 0
      assert page.max_results == 50
      assert page.total == 142
      assert page.is_last == false
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "test", "fixtures", "jira", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
