defmodule Jido.Connect.Notion.LiveSmokeTest do
  @moduledoc """
  Env-gated read-only live smoke hooks for Notion.

  These tests only run when the `NOTION_TOKEN` environment variable is set.
  They exercise real API calls against the Notion API in read-only mode.

  ## Running

      NOTION_TOKEN=xxx mix test .../live_smoke_test.exs --include live_smoke

  These tests are excluded from default runs. Use `--include live_smoke`
  to opt in when credentials are available.

  ## Safety

  - All tests are read-only — no pages, blocks, or comments are created,
    updated, or deleted.
  - No destructive or write actions are exercised.
  - Tokens, secrets, and credential material are never logged or exposed in
    test output.
  """

  use ExUnit.Case, async: true

  @moduletag :live_smoke

  # ── Env guard ─────────────────────────────────────────────────────────

  defp notion_token do
    System.get_env("NOTION_TOKEN")
  end

  defp skip_unless_env_set do
    unless env_configured?() do
      ExUnit.configure(exclude: [:live_smoke])
    end
  end

  defp env_configured? do
    notion_token() != nil and notion_token() != ""
  end

  setup_all do
    skip_unless_env_set()

    if env_configured?() do
      :ok
    else
      {:skip, "NOTION_TOKEN not set — skipping live smoke tests"}
    end
  end

  # ── Helper ────────────────────────────────────────────────────────────

  defp credentials do
    %{
      credentials: %{
        api_key: notion_token()
      }
    }
  end

  # ── Search (read-only) ────────────────────────────────────────────────

  describe "search (live)" do
    test "returns search results" do
      assert {:ok, result} =
               Jido.Connect.Notion.Handlers.Actions.Search.run(
                 %{page_size: 5},
                 credentials()
               )

      assert is_list(result.results)
    end
  end

  # ── Get page (read-only) ──────────────────────────────────────────────

  describe "get page (live)" do
    test "fetches a single page when NOTION_PAGE_ID is set" do
      page_id = System.get_env("NOTION_PAGE_ID")

      if page_id && page_id != "" do
        assert {:ok, %{page: page}} =
                 Jido.Connect.Notion.Handlers.Actions.GetPage.run(
                   %{page_id: page_id},
                   credentials()
                 )

        assert Map.has_key?(page, :id)
      end
    end
  end

  # ── Get database (read-only) ──────────────────────────────────────────

  describe "get database (live)" do
    test "fetches a single database when NOTION_DATABASE_ID is set" do
      database_id = System.get_env("NOTION_DATABASE_ID")

      if database_id && database_id != "" do
        assert {:ok, %{database: database}} =
                 Jido.Connect.Notion.Handlers.Actions.GetDatabase.run(
                   %{database_id: database_id},
                   credentials()
                 )

        assert Map.has_key?(database, :id)
      end
    end
  end

  # ── Query database (read-only) ────────────────────────────────────────

  describe "query database (live)" do
    test "queries database pages when NOTION_DATABASE_ID is set" do
      database_id = System.get_env("NOTION_DATABASE_ID")

      if database_id && database_id != "" do
        assert {:ok, result} =
                 Jido.Connect.Notion.Handlers.Actions.QueryDatabase.run(
                   %{database_id: database_id, page_size: 5},
                   credentials()
                 )

        assert is_list(result.results)
      end
    end
  end

  # ── Retrieve block (read-only) ────────────────────────────────────────

  describe "retrieve block (live)" do
    test "fetches a block when NOTION_PAGE_ID is set" do
      page_id = System.get_env("NOTION_PAGE_ID")

      if page_id && page_id != "" do
        assert {:ok, %{block: block}} =
                 Jido.Connect.Notion.Handlers.Actions.RetrieveBlock.run(
                   %{block_id: page_id},
                   credentials()
                 )

        assert Map.has_key?(block, :id)
      end
    end
  end

  # ── List block children (read-only) ───────────────────────────────────

  describe "list block children (live)" do
    test "lists children of a page when NOTION_PAGE_ID is set" do
      page_id = System.get_env("NOTION_PAGE_ID")

      if page_id && page_id != "" do
        assert {:ok, result} =
                 Jido.Connect.Notion.Handlers.Actions.ListBlockChildren.run(
                   %{block_id: page_id, page_size: 5},
                   credentials()
                 )

        assert is_list(result.results)
      end
    end
  end

  # ── List comments (read-only) ─────────────────────────────────────────

  describe "list comments (live)" do
    test "lists comments on a page when NOTION_PAGE_ID is set" do
      page_id = System.get_env("NOTION_PAGE_ID")

      if page_id && page_id != "" do
        assert {:ok, result} =
                 Jido.Connect.Notion.Handlers.Actions.ListComments.run(
                   %{block_id: page_id, page_size: 5},
                   credentials()
                 )

        assert is_list(result.results)
      end
    end
  end
end
