defmodule Jido.Connect.Linear.FixtureTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Linear.Client.Normalizer

  describe "issue fixtures" do
    test "normalizes common issue fixture" do
      payload = fixture!("issue_common.json")

      assert {:ok, issue} = Normalizer.issue(payload)
      assert issue.id == "uuid-001"
      assert issue.identifier == "LIN-123"
      assert issue.title == "Implement user authentication flow"
      assert issue.description == "We need to add OAuth2 support for the login flow."
      assert issue.priority_label == "Medium"
      assert issue.due_date == "2026-06-15"
      assert issue.estimate == 5.0
      assert length(issue.labels) == 2
      assert issue.created_at == "2026-04-10T08:30:00.000Z"
      assert issue.updated_at == "2026-05-15T14:22:00.000Z"
    end

    test "normalizes issue state" do
      payload = fixture!("issue_common.json")

      assert {:ok, issue} = Normalizer.issue(payload)
      assert issue.state.id == "status-3"
      assert issue.state.name == "In Progress"
      assert issue.state.type == "started"
      assert issue.state.color == "#F2C94C"
    end

    test "normalizes issue assignee and creator" do
      payload = fixture!("issue_common.json")

      assert {:ok, issue} = Normalizer.issue(payload)
      assert issue.assignee.id == "user-1"
      assert issue.assignee.name == "Alice Nakamura"
      assert issue.assignee.email == "alice@example.com"
      assert issue.assignee.display_name == "Alice Nakamura"
      assert issue.assignee.active == true

      assert issue.creator.id == "user-2"
      assert issue.creator.name == "Bob Martinez"
    end

    test "normalizes issue team brief" do
      payload = fixture!("issue_common.json")

      assert {:ok, issue} = Normalizer.issue(payload)
      assert issue.team.id == "team-1"
      assert issue.team.key == "LIN"
      assert issue.team.name == "Linear Team"
    end

    test "normalizes issue priority" do
      payload = fixture!("issue_common.json")

      assert {:ok, issue} = Normalizer.issue(payload)
      assert issue.priority.value == 3
      assert issue.priority.label == "Medium"
    end

    test "normalizes issue labels from connection nodes" do
      payload = fixture!("issue_common.json")

      assert {:ok, issue} = Normalizer.issue(payload)
      assert length(issue.labels) == 2
      assert Enum.at(issue.labels, 0).id == "label-1"
      assert Enum.at(issue.labels, 0).name == "backend"
      assert Enum.at(issue.labels, 0).color == "#E5484D"
      assert Enum.at(issue.labels, 1).name == "auth"
    end

    test "normalizes issue search results fixture" do
      payload = fixture!("issue_search_results.json")

      nodes = payload["nodes"]
      page_info = Map.merge(payload["pageInfo"], %{"totalCount" => payload["totalCount"]})

      assert {:ok, page} = Normalizer.pagination(page_info)
      assert page.has_next_page == false
      assert page.end_cursor == "cursor-def456"
      assert page.total_count == 2
      assert length(nodes) == 2

      assert {:ok, first} = Normalizer.issue(Enum.at(nodes, 0))
      assert first.identifier == "LIN-123"
      assert first.state.name == "In Progress"

      assert {:ok, second} = Normalizer.issue(Enum.at(nodes, 1))
      assert second.identifier == "LIN-124"
      assert second.title == "Fix login redirect loop"
      assert second.priority.value == 1
      assert second.priority.label == "Urgent"
      assert length(second.labels) == 1
    end
  end

  describe "team fixtures" do
    test "normalizes common team fixture" do
      payload = fixture!("team_common.json")

      assert {:ok, team} = Normalizer.team(payload)
      assert team.id == "team-1"
      assert team.key == "LIN"
      assert team.name == "Linear Team"
      assert team.description == "Core Linear product team."
      assert team.icon == "🚀"
      assert team.color == "#5B5DEF"
    end

    test "normalizes team lead as user" do
      payload = fixture!("team_common.json")

      assert {:ok, team} = Normalizer.team(payload)
      assert team.lead.id == "user-1"
      assert team.lead.name == "Alice Nakamura"
      assert team.lead.email == "alice@example.com"
    end

    test "normalizes teams list fixture" do
      payload = fixture!("teams_list.json")

      nodes = payload["nodes"]
      assert length(nodes) == 2

      assert {:ok, first} = Normalizer.team(Enum.at(nodes, 0))
      assert first.key == "LIN"
      assert first.name == "Linear Team"

      assert {:ok, second} = Normalizer.team(Enum.at(nodes, 1))
      assert second.key == "ENG"
      assert second.name == "Engineering"

      page_info = payload["pageInfo"]
      assert {:ok, page} = Normalizer.pagination(page_info)
      assert page.has_next_page == false
    end
  end

  describe "user fixtures" do
    test "normalizes common user fixture" do
      payload = fixture!("user_common.json")

      assert {:ok, user} = Normalizer.user(payload)
      assert user.id == "user-1"
      assert user.name == "Alice Nakamura"
      assert user.display_name == "Alice Nakamura"
      assert user.email == "alice@example.com"
      assert user.avatar_url == "https://avatars.linear.app/user-1"
      assert user.active == true
    end
  end

  describe "state fixtures" do
    test "normalizes common state fixture" do
      payload = fixture!("state_common.json")

      assert {:ok, state} = Normalizer.state(payload)
      assert state.id == "status-3"
      assert state.name == "In Progress"
      assert state.type == "started"
      assert state.color == "#F2C94C"
      assert state.description == "Issue is being actively worked on."
    end
  end

  describe "label fixtures" do
    test "normalizes common label fixture" do
      payload = fixture!("label_common.json")

      assert {:ok, label} = Normalizer.label(payload)
      assert label.id == "label-1"
      assert label.name == "backend"
      assert label.color == "#E5484D"
      assert label.description == "Backend engineering work."
      assert label.is_group == false
    end
  end

  describe "comment fixtures" do
    test "normalizes common comment fixture" do
      payload = fixture!("comment_common.json")

      assert {:ok, comment} = Normalizer.comment(payload)
      assert comment.id == "comment-1"
      assert comment.body == "Investigated the OAuth2 flow. Ready to start implementation."
      assert comment.parent_id == "uuid-001"
      assert comment.created_at == "2026-05-01T10:30:00.000Z"
      assert comment.updated_at == "2026-05-01T10:30:00.000Z"
    end

    test "normalizes comment author" do
      payload = fixture!("comment_common.json")

      assert {:ok, comment} = Normalizer.comment(payload)
      assert comment.author.id == "user-1"
      assert comment.author.name == "Alice Nakamura"
    end
  end

  describe "pagination fixtures" do
    test "normalizes common pagination fixture" do
      payload = fixture!("pagination_common.json")

      assert {:ok, page} = Normalizer.pagination(payload)
      assert page.has_next_page == true
      assert page.end_cursor == "cursor-abc123"
      assert page.total_count == 142
    end
  end

  describe "comments list fixture" do
    test "normalizes comments list fixture" do
      payload = fixture!("comments_list.json")

      nodes = payload["nodes"]
      page_info = Map.merge(payload["pageInfo"], %{"totalCount" => payload["totalCount"]})

      assert {:ok, page} = Normalizer.pagination(page_info)
      assert page.has_next_page == false
      assert page.end_cursor == "cursor-comment-2"
      assert page.total_count == 2
      assert length(nodes) == 2

      assert {:ok, first} = Normalizer.comment(Enum.at(nodes, 0))
      assert first.id == "comment-1"
      assert first.body == "Investigated the OAuth2 flow. Ready to start implementation."
      assert first.author.id == "user-1"
      assert first.author.name == "Alice Nakamura"
      assert first.parent_id == "uuid-001"
      assert first.created_at == "2026-05-01T10:30:00.000Z"

      assert {:ok, second} = Normalizer.comment(Enum.at(nodes, 1))
      assert second.id == "comment-2"
      assert second.author.name == "Bob Martinez"
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "test", "fixtures", "linear", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
