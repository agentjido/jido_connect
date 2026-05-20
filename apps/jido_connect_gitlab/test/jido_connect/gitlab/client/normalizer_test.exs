defmodule Jido.Connect.GitLab.Client.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.GitLab.Client.Normalizer

  describe "user/1" do
    test "normalizes a map with all fields" do
      assert {:ok, user} =
               Normalizer.user(%{
                 "id" => 42,
                 "username" => "alice_dev",
                 "name" => "Alice Nakamura",
                 "email" => "alice@example.com",
                 "avatar_url" => "https://gitlab.example.com/avatar.png",
                 "state" => "active",
                 "web_url" => "https://gitlab.example.com/alice_dev"
               })

      assert user.id == 42
      assert user.username == "alice_dev"
      assert user.name == "Alice Nakamura"
      assert user.email == "alice@example.com"
      assert user.state == "active"
    end

    test "normalizes with only required id" do
      assert {:ok, user} = Normalizer.user(%{"id" => 1})
      assert user.id == 1
      assert user.username == nil
    end

    test "returns error for non-map" do
      assert {:error, :invalid_user_payload} = Normalizer.user("not a map")
    end
  end

  describe "project/1" do
    test "normalizes a full project payload" do
      assert {:ok, project} =
               Normalizer.project(%{
                 "id" => 101,
                 "name" => "jido_connect",
                 "path" => "jido_connect",
                 "path_with_namespace" => "engineering/jido_connect",
                 "description" => "A connector framework.",
                 "default_branch" => "main",
                 "visibility" => "private",
                 "web_url" => "https://gitlab.example.com/engineering/jido_connect",
                 "ssh_url_to_repo" => "git@gitlab.example.com:engineering/jido_connect.git",
                 "http_url_to_repo" => "https://gitlab.example.com/engineering/jido_connect.git",
                 "namespace" => %{"id" => 7, "name" => "Engineering", "path" => "engineering"},
                 "owner" => %{"id" => 42, "username" => "alice_dev", "name" => "Alice"},
                 "star_count" => 5,
                 "forks_count" => 2,
                 "open_issues_count" => 12,
                 "created_at" => "2025-06-01T09:00:00.000Z",
                 "updated_at" => "2026-05-15T14:30:00.000Z"
               })

      assert project.id == 101
      assert project.name == "jido_connect"
      assert project.path_with_namespace == "engineering/jido_connect"
      assert project.visibility == "private"
      assert project.default_branch == "main"
      assert project.star_count == 5
      assert project.owner.id == 42
      assert project.owner.name == "Alice"
      assert project.namespace["path"] == "engineering"
    end

    test "returns error for non-map" do
      assert {:error, :invalid_project_payload} = Normalizer.project(nil)
    end
  end

  describe "issue/1" do
    test "normalizes a full issue payload" do
      assert {:ok, issue} =
               Normalizer.issue(%{
                 "id" => 201,
                 "iid" => 14,
                 "title" => "Fix OAuth token refresh edge case",
                 "description" => "Refresh token issue.",
                 "state" => "opened",
                 "labels" => [
                   %{"id" => 1, "name" => "bug", "color" => "#FF0000"},
                   %{"id" => 2, "name" => "auth", "color" => "#5B5DEF"}
                 ],
                 "milestone" => %{"id" => 5, "title" => "v2.0 Release"},
                 "assignees" => [%{"id" => 42, "username" => "alice_dev"}],
                 "author" => %{"id" => 43, "username" => "bob_eng", "name" => "Bob"},
                 "project_id" => 101,
                 "web_url" => "https://gitlab.example.com/engineering/jido_connect/-/issues/14",
                 "created_at" => "2026-04-10T08:30:00.000Z",
                 "updated_at" => "2026-05-15T14:22:00.000Z",
                 "closed_at" => nil
               })

      assert issue.id == 201
      assert issue.iid == 14
      assert issue.title == "Fix OAuth token refresh edge case"
      assert issue.state == "opened"
      assert length(issue.labels) == 2
      assert Enum.at(issue.labels, 0).name == "bug"
      assert Enum.at(issue.labels, 1).name == "auth"
      assert issue.author.id == 43
      assert issue.author.name == "Bob"
      assert length(issue.assignees) == 1
      assert Enum.at(issue.assignees, 0).id == 42
      assert issue.milestone["title"] == "v2.0 Release"
      assert issue.project_id == 101
    end

    test "normalizes labels given as strings" do
      assert {:ok, issue} =
               Normalizer.issue(%{
                 "id" => 202,
                 "iid" => 15,
                 "labels" => ["bug", "feature"]
               })

      assert length(issue.labels) == 2
      assert Enum.at(issue.labels, 0).name == "bug"
      assert Enum.at(issue.labels, 1).name == "feature"
    end

    test "returns error for non-map" do
      assert {:error, :invalid_issue_payload} = Normalizer.issue("bad")
    end
  end

  describe "merge_request/1" do
    test "normalizes a full merge request payload" do
      assert {:ok, mr} =
               Normalizer.merge_request(%{
                 "id" => 301,
                 "iid" => 7,
                 "title" => "Add structs",
                 "description" => "Normalized structs.",
                 "state" => "merged",
                 "merge_status" => "can_be_merged",
                 "source_branch" => "feature/structs",
                 "target_branch" => "main",
                 "author" => %{"id" => 42, "username" => "alice_dev"},
                 "assignees" => [%{"id" => 42}],
                 "reviewers" => [%{"id" => 43}],
                 "project_id" => 101,
                 "source_project_id" => 101,
                 "target_project_id" => 101,
                 "web_url" => "https://gitlab.example.com/eng/jido/-/merge_requests/7",
                 "created_at" => "2026-05-01T10:00:00.000Z",
                 "updated_at" => "2026-05-10T16:45:00.000Z",
                 "merged_at" => "2026-05-10T16:45:00.000Z"
               })

      assert mr.id == 301
      assert mr.iid == 7
      assert mr.state == "merged"
      assert mr.merge_status == "can_be_merged"
      assert mr.source_branch == "feature/structs"
      assert mr.target_branch == "main"
      assert mr.author.id == 42
      assert length(mr.assignees) == 1
      assert length(mr.reviewers) == 1
      assert mr.merged_at == "2026-05-10T16:45:00.000Z"
    end

    test "returns error for non-map" do
      assert {:error, :invalid_merge_request_payload} = Normalizer.merge_request(nil)
    end
  end

  describe "note/1" do
    test "normalizes a full note payload" do
      assert {:ok, note} =
               Normalizer.note(%{
                 "id" => 501,
                 "body" => "Investigated the issue.",
                 "attachment" => nil,
                 "author" => %{"id" => 42, "username" => "alice_dev", "name" => "Alice"},
                 "noteable_id" => 201,
                 "noteable_type" => "Issue",
                 "system" => false,
                 "created_at" => "2026-05-01T10:30:00.000Z",
                 "updated_at" => "2026-05-01T10:30:00.000Z"
               })

      assert note.id == 501
      assert note.body == "Investigated the issue."
      assert note.author.id == 42
      assert note.noteable_type == "Issue"
      assert note.noteable_id == 201
      assert note.system == false
    end

    test "returns error for non-map" do
      assert {:error, :invalid_note_payload} = Normalizer.note("bad")
    end
  end

  describe "label/1" do
    test "normalizes a label payload" do
      assert {:ok, label} =
               Normalizer.label(%{
                 "id" => 1,
                 "name" => "bug",
                 "color" => "#FF0000",
                 "text_color" => "#FFFFFF",
                 "description" => "Something isn't working"
               })

      assert label.id == 1
      assert label.name == "bug"
      assert label.color == "#FF0000"
      assert label.text_color == "#FFFFFF"
      assert label.description == "Something isn't working"
    end

    test "returns error for non-map" do
      assert {:error, :invalid_label_payload} = Normalizer.label(nil)
    end
  end

  describe "pipeline/1" do
    test "normalizes a full pipeline payload" do
      assert {:ok, pipeline} =
               Normalizer.pipeline(%{
                 "id" => 401,
                 "sha" => "a1b2c3d4e5f6",
                 "ref" => "main",
                 "status" => "success",
                 "source" => "push",
                 "user" => %{"id" => 42, "username" => "alice_dev"},
                 "project_id" => 101,
                 "web_url" => "https://gitlab.example.com/eng/jido/-/pipelines/401",
                 "created_at" => "2026-05-15T14:00:00.000Z",
                 "updated_at" => "2026-05-15T14:12:00.000Z",
                 "started_at" => "2026-05-15T14:01:00.000Z",
                 "finished_at" => "2026-05-15T14:12:00.000Z"
               })

      assert pipeline.id == 401
      assert pipeline.sha == "a1b2c3d4e5f6"
      assert pipeline.ref == "main"
      assert pipeline.status == "success"
      assert pipeline.source == "push"
      assert pipeline.user.id == 42
      assert pipeline.project_id == 101
    end

    test "returns error for non-map" do
      assert {:error, :invalid_pipeline_payload} = Normalizer.pipeline("bad")
    end
  end

  describe "job/1" do
    test "normalizes a full job payload" do
      assert {:ok, job} =
               Normalizer.job(%{
                 "id" => 601,
                 "name" => "test",
                 "stage" => "test",
                 "status" => "success",
                 "ref" => "main",
                 "tag" => false,
                 "user" => %{"id" => 42, "username" => "alice_dev"},
                 "pipeline" => %{"id" => 401},
                 "web_url" => "https://gitlab.example.com/eng/jido/-/jobs/601",
                 "runner" => %{"id" => 10, "description" => "shared-runner-1"},
                 "created_at" => "2026-05-15T14:01:00.000Z",
                 "started_at" => "2026-05-15T14:02:00.000Z",
                 "finished_at" => "2026-05-15T14:10:00.000Z"
               })

      assert job.id == 601
      assert job.name == "test"
      assert job.stage == "test"
      assert job.status == "success"
      assert job.ref == "main"
      assert job.tag == false
      assert job.user.id == 42
      assert job.pipeline_id == 401
      assert job.runner["id"] == 10
    end

    test "extracts pipeline_id from integer" do
      assert {:ok, job} =
               Normalizer.job(%{
                 "id" => 602,
                 "pipeline" => 401
               })

      assert job.pipeline_id == 401
    end

    test "returns error for non-map" do
      assert {:error, :invalid_job_payload} = Normalizer.job(nil)
    end
  end

  describe "commit/1" do
    test "normalizes a full commit payload" do
      assert {:ok, commit} =
               Normalizer.commit(%{
                 "id" => "a1b2c3d4e5f6a7b8c9d0",
                 "short_id" => "a1b2c3d4",
                 "title" => "Add structs",
                 "message" => "Add structs\n\nDetailed message.",
                 "author_name" => "Alice Nakamura",
                 "author_email" => "alice@example.com",
                 "authored_date" => "2026-05-15T13:50:00.000Z",
                 "committer_name" => "Alice Nakamura",
                 "committer_email" => "alice@example.com",
                 "committed_date" => "2026-05-15T13:55:00.000Z",
                 "web_url" => "https://gitlab.example.com/eng/jido/-/commit/a1b2c3d4e5f6"
               })

      assert commit.id == "a1b2c3d4e5f6a7b8c9d0"
      assert commit.short_id == "a1b2c3d4"
      assert commit.title == "Add structs"
      assert commit.author_name == "Alice Nakamura"
      assert commit.author_email == "alice@example.com"
    end

    test "returns error for non-map" do
      assert {:error, :invalid_commit_payload} = Normalizer.commit("bad")
    end
  end

  describe "pagination/1" do
    test "normalizes header-style keys" do
      assert {:ok, page} =
               Normalizer.pagination(%{
                 "x-page" => 1,
                 "x-per-page" => 20,
                 "x-total" => 42,
                 "x-total-pages" => 3,
                 "x-next-page" => 2,
                 "x-prev-page" => nil
               })

      assert page.page == 1
      assert page.per_page == 20
      assert page.total == 42
      assert page.total_pages == 3
      assert page.next_page == 2
    end

    test "normalizes plain keys" do
      assert {:ok, page} =
               Normalizer.pagination(%{
                 "page" => 2,
                 "per_page" => 10,
                 "total" => 25,
                 "total_pages" => 3
               })

      assert page.page == 2
      assert page.per_page == 10
      assert page.total == 25
    end

    test "prefers header-style keys when both present" do
      assert {:ok, page} =
               Normalizer.pagination(%{
                 "x-page" => 3,
                 "page" => 99
               })

      assert page.page == 3
    end

    test "returns error for non-map" do
      assert {:error, :invalid_pagination_payload} = Normalizer.pagination(nil)
    end
  end
end
