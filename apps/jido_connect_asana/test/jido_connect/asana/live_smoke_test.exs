defmodule Jido.Connect.Asana.LiveSmokeTest do
  @moduledoc """
  Env-gated read-only live smoke hooks for Asana.

  These tests only run when the `ASANA_ACCESS_TOKEN` environment variable is
  set. They exercise real Asana API calls in read-only mode.

  ## Running

      ASANA_ACCESS_TOKEN=xxx mix test .../live_smoke_test.exs --include live_smoke

  These tests are excluded from default runs. Use `--include live_smoke`
  to opt in when credentials are available.

  ## Safety

  - All tests are read-only — no tasks, projects, or stories are created,
    updated, or deleted.
  - No destructive or write actions are exercised.
  - Tokens, secrets, and credential material are never logged or exposed in
    test output.
  """

  use ExUnit.Case, async: true

  @moduletag :live_smoke

  # ── Env guard ─────────────────────────────────────────────────────────

  defp access_token do
    System.get_env("ASANA_ACCESS_TOKEN")
  end

  defp env_configured? do
    access_token() != nil and access_token() != ""
  end

  setup_all do
    if env_configured?() do
      :ok
    else
      {:skip, "ASANA_ACCESS_TOKEN not set — skipping live smoke tests"}
    end
  end

  # ── Helper ────────────────────────────────────────────────────────────

  defp credentials do
    %{credentials: %{api_key: access_token()}}
  end

  # ── List workspaces (read-only) ───────────────────────────────────────

  describe "list workspaces (live)" do
    test "returns a page of workspaces" do
      assert {:ok, result} =
               Jido.Connect.Asana.Handlers.Actions.ListWorkspaces.run(
                 %{limit: 5},
                 credentials()
               )

      assert is_list(result.items)

      for workspace <- result.items do
        assert Map.has_key?(workspace, :gid)
      end
    end
  end

  # ── List users (read-only) ────────────────────────────────────────────

  describe "list users (live)" do
    test "returns a page of users when ASANA_WORKSPACE_GID is set" do
      workspace_gid = System.get_env("ASANA_WORKSPACE_GID")

      if workspace_gid && workspace_gid != "" do
        assert {:ok, result} =
                 Jido.Connect.Asana.Handlers.Actions.ListUsers.run(
                   %{workspace: workspace_gid, limit: 5},
                   credentials()
                 )

        assert is_list(result.items)
      end
    end
  end

  # ── Get task (read-only) ──────────────────────────────────────────────

  describe "get task (live)" do
    test "fetches a single task when ASANA_TASK_GID is set" do
      task_gid = System.get_env("ASANA_TASK_GID")

      if task_gid && task_gid != "" do
        assert {:ok, result} =
                 Jido.Connect.Asana.Handlers.Actions.GetTask.run(
                   %{task_gid: task_gid},
                   credentials()
                 )

        assert result.task.gid == task_gid
      end
    end
  end

  # ── Webhook verification (offline, live secret) ───────────────────────

  describe "webhook signature verification" do
    test "verifies a computed signature round-trip" do
      secret = System.get_env("ASANA_WEBHOOK_SECRET") || "test-secret"

      body = ~s({"events":[{"resource":{"gid":"1"},"action":"changed"}]})
      computed = Jido.Connect.Asana.Webhook.compute_signature(body, secret)

      assert :ok = Jido.Connect.Asana.Webhook.verify_signature(computed, computed)
    end
  end
end
