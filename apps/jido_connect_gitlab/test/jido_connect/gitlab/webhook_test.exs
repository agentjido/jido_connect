defmodule Jido.Connect.GitLab.WebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.GitLab.Webhook

  describe "supported_events/0" do
    test "returns list of supported event types" do
      events = Webhook.supported_events()
      assert :push in events
      assert :issue in events
      assert :merge_request in events
      assert :note in events
      assert :pipeline in events
      assert :job in events
    end
  end

  describe "parse_event_type/1" do
    test "parses known event headers" do
      assert {:ok, :push} = Webhook.parse_event_type("Push Hook")
      assert {:ok, :issue} = Webhook.parse_event_type("Issue Hook")
      assert {:ok, :merge_request} = Webhook.parse_event_type("Merge Request Hook")
      assert {:ok, :note} = Webhook.parse_event_type("Note Hook")
      assert {:ok, :pipeline} = Webhook.parse_event_type("Pipeline Hook")
      assert {:ok, :job} = Webhook.parse_event_type("Job Hook")
      assert {:ok, :tag_push} = Webhook.parse_event_type("Tag Push Hook")
    end

    test "returns error for unknown event header" do
      assert {:error, error} = Webhook.parse_event_type("Unknown Hook")
      assert error.reason == :unsupported_webhook_event
    end

    test "returns error for nil" do
      assert {:error, error} = Webhook.parse_event_type(nil)
      assert error.reason == :webhook_event_missing
    end
  end

  describe "verify_token/2" do
    test "returns :ok when tokens match" do
      assert :ok = Webhook.verify_token("test-token-abc123", "test-token-abc123")
    end

    test "returns error when tokens differ" do
      assert {:error, error} = Webhook.verify_token("wrong-token", "expected-token")
      assert error.reason == :webhook_token_mismatch
    end

    test "returns error when token is nil" do
      assert {:error, error} = Webhook.verify_token(nil, "expected")
      assert error.reason == :webhook_token_missing
    end
  end

  describe "normalize_event/2 — push" do
    test "normalizes push webhook fixture" do
      payload = fixture!("webhook_push.json")

      assert {:ok, signal} = Webhook.normalize_event(:push, payload)
      assert signal.event_type == :push
      assert signal.ref == "refs/heads/main"
      assert signal.project_id == 101
      assert signal.project_path == "engineering/jido_connect"
      assert signal.user_name == "Alice Nakamura"
      assert length(signal.commits) == 1
      assert signal.total_commits_count == 1
    end
  end

  describe "normalize_event/2 — issue" do
    test "normalizes issue opened webhook fixture" do
      payload = fixture!("webhook_issue_opened.json")

      assert {:ok, signal} = Webhook.normalize_event(:issue, payload)
      assert signal.event_type == :issue
      assert signal.action == "open"
      assert signal.issue_id == 201
      assert signal.issue_iid == 14
      assert signal.title == "Fix OAuth token refresh edge case"
      assert signal.state == "opened"
      assert signal.project_id == 101
      assert signal.author_id == 42
      assert signal.author_username == "alice_dev"
      assert signal.labels == ["bug", "auth"]
    end
  end

  describe "normalize_event/2 — merge_request" do
    test "normalizes merge request merged webhook fixture" do
      payload = fixture!("webhook_merge_request_merged.json")

      assert {:ok, signal} = Webhook.normalize_event(:merge_request, payload)
      assert signal.event_type == :merge_request
      assert signal.action == "merge"
      assert signal.merge_request_id == 301
      assert signal.merge_request_iid == 7
      assert signal.state == "merged"
      assert signal.merge_status == "can_be_merged"
      assert signal.source_branch == "feature/gitlab-structs"
      assert signal.target_branch == "main"
      assert signal.merged_at == "2026-05-10T16:45:00.000Z"
      assert signal.author_id == 42
    end
  end

  describe "normalize_event/2 — note" do
    test "normalizes note on issue webhook fixture" do
      payload = fixture!("webhook_note_issue.json")

      assert {:ok, signal} = Webhook.normalize_event(:note, payload)
      assert signal.event_type == :note
      assert signal.note_id == 501
      assert signal.noteable_type == "Issue"
      assert signal.noteable_id == 201

      assert signal.body ==
               "Investigated the refresh flow. The issue is in the retry logic after a 401."

      assert signal.author_id == 42
      assert signal.project_id == 101
    end
  end

  describe "normalize_event/2 — pipeline" do
    test "normalizes pipeline webhook fixture" do
      payload = fixture!("webhook_pipeline.json")

      assert {:ok, signal} = Webhook.normalize_event(:pipeline, payload)
      assert signal.event_type == :pipeline
      assert signal.pipeline_id == 401
      assert signal.status == "success"
      assert signal.ref == "main"
      assert signal.sha == "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0"
      assert signal.source == "push"
      assert signal.project_id == 101
      assert signal.user_id == 42
    end
  end

  describe "normalize_event/2 — job" do
    test "normalizes job webhook fixture" do
      payload = fixture!("webhook_job.json")

      assert {:ok, signal} = Webhook.normalize_event(:job, payload)
      assert signal.event_type == :job
      assert signal.job_id == 601
      assert signal.name == "test"
      assert signal.stage == "test"
      assert signal.status == "success"
      assert signal.ref == "main"
      assert signal.pipeline_id == 401
      assert signal.project_id == 101
      assert signal.runner_id == 10
      assert signal.user_id == 42
    end
  end

  describe "normalize_event/2 — tag_push" do
    test "normalizes tag_push event" do
      payload = %{
        "ref" => "refs/tags/v1.0.0",
        "before" => "0000000000000000000000000000000000000000",
        "after" => "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0",
        "project" => %{
          "id" => 101,
          "path_with_namespace" => "engineering/jido_connect"
        },
        "user_name" => "Alice Nakamura"
      }

      assert {:ok, signal} = Webhook.normalize_event(:tag_push, payload)
      assert signal.event_type == :tag_push
      assert signal.ref == "refs/tags/v1.0.0"
      assert signal.project_id == 101
    end
  end

  describe "normalize_event/2 — errors" do
    test "returns error for unsupported event type" do
      assert {:error, error} = Webhook.normalize_event(:unknown, %{})
      assert error.reason == :unsupported_webhook_event
    end

    test "returns error for missing object_attributes on issue" do
      assert {:error, error} = Webhook.normalize_event(:issue, %{"no_attrs" => true})
      assert error.reason == :invalid_webhook_event
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "test", "fixtures", "gitlab", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
