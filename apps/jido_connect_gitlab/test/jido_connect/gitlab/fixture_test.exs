defmodule Jido.Connect.GitLab.FixtureTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.GitLab.Client.Normalizer

  describe "user fixtures" do
    test "normalizes common user fixture" do
      payload = fixture!("user_common.json")

      assert {:ok, user} = Normalizer.user(payload)
      assert user.id == 42
      assert user.username == "alice_dev"
      assert user.name == "Alice Nakamura"
      assert user.email == "alice@example.com"
      assert user.avatar_url == "https://gitlab.example.com/uploads/user/avatar/42/avatar.png"
      assert user.state == "active"
      assert user.web_url == "https://gitlab.example.com/alice_dev"
    end
  end

  describe "project fixtures" do
    test "normalizes common project fixture" do
      payload = fixture!("project_common.json")

      assert {:ok, project} = Normalizer.project(payload)
      assert project.id == 101
      assert project.name == "jido_connect"
      assert project.path == "jido_connect"
      assert project.path_with_namespace == "engineering/jido_connect"
      assert project.description == "A connector framework for Jido agents."
      assert project.default_branch == "main"
      assert project.visibility == "private"
      assert project.star_count == 5
      assert project.forks_count == 2
      assert project.open_issues_count == 12
    end

    test "normalizes project owner" do
      payload = fixture!("project_common.json")

      assert {:ok, project} = Normalizer.project(payload)
      assert project.owner.id == 42
      assert project.owner.username == "alice_dev"
    end

    test "normalizes project namespace" do
      payload = fixture!("project_common.json")

      assert {:ok, project} = Normalizer.project(payload)
      assert project.namespace["id"] == 7
      assert project.namespace["path"] == "engineering"
    end
  end

  describe "issue fixtures" do
    test "normalizes common issue fixture" do
      payload = fixture!("issue_common.json")

      assert {:ok, issue} = Normalizer.issue(payload)
      assert issue.id == 201
      assert issue.iid == 14
      assert issue.title == "Fix OAuth token refresh edge case"

      assert issue.description ==
               "When the refresh token expires mid-session, the client should surface a re-auth prompt."

      assert issue.state == "opened"
      assert issue.project_id == 101
      assert issue.web_url == "https://gitlab.example.com/engineering/jido_connect/-/issues/14"
      assert issue.created_at == "2026-04-10T08:30:00.000Z"
      assert issue.updated_at == "2026-05-15T14:22:00.000Z"
    end

    test "normalizes issue labels" do
      payload = fixture!("issue_common.json")

      assert {:ok, issue} = Normalizer.issue(payload)
      assert length(issue.labels) == 2
      assert Enum.at(issue.labels, 0).id == 1
      assert Enum.at(issue.labels, 0).name == "bug"
      assert Enum.at(issue.labels, 0).color == "#FF0000"
      assert Enum.at(issue.labels, 1).name == "auth"
    end

    test "normalizes issue author and assignees" do
      payload = fixture!("issue_common.json")

      assert {:ok, issue} = Normalizer.issue(payload)
      assert issue.author.id == 43
      assert issue.author.username == "bob_eng"
      assert length(issue.assignees) == 1
      assert Enum.at(issue.assignees, 0).id == 42
      assert Enum.at(issue.assignees, 0).username == "alice_dev"
    end

    test "normalizes issue milestone" do
      payload = fixture!("issue_common.json")

      assert {:ok, issue} = Normalizer.issue(payload)
      assert issue.milestone["id"] == 5
      assert issue.milestone["title"] == "v2.0 Release"
    end
  end

  describe "merge request fixtures" do
    test "normalizes common merge request fixture" do
      payload = fixture!("merge_request_common.json")

      assert {:ok, mr} = Normalizer.merge_request(payload)
      assert mr.id == 301
      assert mr.iid == 7
      assert mr.title == "Add normalized structs for GitLab entities"
      assert mr.state == "merged"
      assert mr.merge_status == "can_be_merged"
      assert mr.source_branch == "feature/gitlab-structs"
      assert mr.target_branch == "main"
      assert mr.project_id == 101
      assert mr.merged_at == "2026-05-10T16:45:00.000Z"
    end

    test "normalizes merge request author, assignees, and reviewers" do
      payload = fixture!("merge_request_common.json")

      assert {:ok, mr} = Normalizer.merge_request(payload)
      assert mr.author.id == 42
      assert length(mr.assignees) == 1
      assert Enum.at(mr.assignees, 0).id == 42
      assert length(mr.reviewers) == 1
      assert Enum.at(mr.reviewers, 0).id == 43
    end
  end

  describe "note fixtures" do
    test "normalizes common note fixture" do
      payload = fixture!("note_common.json")

      assert {:ok, note} = Normalizer.note(payload)
      assert note.id == 501

      assert note.body ==
               "Investigated the refresh flow. The issue is in the retry logic after a 401."

      assert note.noteable_id == 201
      assert note.noteable_type == "Issue"
      assert note.system == false
    end

    test "normalizes note author" do
      payload = fixture!("note_common.json")

      assert {:ok, note} = Normalizer.note(payload)
      assert note.author.id == 42
      assert note.author.username == "alice_dev"
    end
  end

  describe "label fixtures" do
    test "normalizes common label fixture" do
      payload = fixture!("label_common.json")

      assert {:ok, label} = Normalizer.label(payload)
      assert label.id == 1
      assert label.name == "bug"
      assert label.color == "#FF0000"
      assert label.text_color == "#FFFFFF"
      assert label.description == "Something isn't working"
    end
  end

  describe "pipeline fixtures" do
    test "normalizes common pipeline fixture" do
      payload = fixture!("pipeline_common.json")

      assert {:ok, pipeline} = Normalizer.pipeline(payload)
      assert pipeline.id == 401
      assert pipeline.sha == "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0"
      assert pipeline.ref == "main"
      assert pipeline.status == "success"
      assert pipeline.source == "push"
      assert pipeline.project_id == 101
    end

    test "normalizes pipeline user" do
      payload = fixture!("pipeline_common.json")

      assert {:ok, pipeline} = Normalizer.pipeline(payload)
      assert pipeline.user.id == 42
      assert pipeline.user.username == "alice_dev"
    end
  end

  describe "job fixtures" do
    test "normalizes common job fixture" do
      payload = fixture!("job_common.json")

      assert {:ok, job} = Normalizer.job(payload)
      assert job.id == 601
      assert job.name == "test"
      assert job.stage == "test"
      assert job.status == "success"
      assert job.ref == "main"
      assert job.tag == false
      assert job.pipeline_id == 401
    end

    test "normalizes job user and runner" do
      payload = fixture!("job_common.json")

      assert {:ok, job} = Normalizer.job(payload)
      assert job.user.id == 42
      assert job.runner["id"] == 10
    end
  end

  describe "commit fixtures" do
    test "normalizes common commit fixture" do
      payload = fixture!("commit_common.json")

      assert {:ok, commit} = Normalizer.commit(payload)
      assert commit.id == "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0"
      assert commit.short_id == "a1b2c3d4"
      assert commit.title == "Add GitLab normalized structs"
      assert commit.author_name == "Alice Nakamura"
      assert commit.author_email == "alice@example.com"
      assert commit.committer_name == "Alice Nakamura"
    end
  end

  describe "pagination fixtures" do
    test "normalizes common pagination fixture" do
      payload = fixture!("pagination_common.json")

      assert {:ok, page} = Normalizer.pagination(payload)
      assert page.page == 1
      assert page.per_page == 20
      assert page.total == 42
      assert page.total_pages == 3
      assert page.next_page == 2
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "test", "fixtures", "gitlab", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
