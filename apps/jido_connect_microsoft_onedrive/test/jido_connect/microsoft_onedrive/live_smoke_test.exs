defmodule Jido.Connect.MicrosoftOnedrive.LiveSmokeTest do
  @moduledoc """
  Env-gated live smoke hooks for Microsoft OneDrive.

  These tests only run when the `MICROSOFT_ACCESS_TOKEN` environment variable
  is set to a valid Microsoft Graph OAuth token with the appropriate scopes.
  They exercise real API calls against the authenticated user's OneDrive.

  ## Running

      MICROSOFT_ACCESS_TOKEN="eyJ..." mix test .../live_smoke_test.exs --include live_smoke

  These tests are excluded from default runs. Use `--include live_smoke`
  to opt in when credentials are available.

  ## Safety

  - Read-only tests exercise list, get, search, and delta endpoints.
  - Destructive and write tests are gated behind `MICROSOFT_LIVE_DESTRUCTIVE`
    to prevent accidental data mutation in live environments.
  - No tokens, secrets, or credential material are ever logged or exposed in
    test output.

  ## Permission semantics

  Microsoft Graph permission resources represent access grants on drive items.
  - **Sharing links** (`createLink`) create URL-based access with `view` or
    `edit` roles. Links may be scoped to `anonymous`, `organization`, or
    `users`.
  - **Invitations** (`invite`) grant user or group access via email with
    `read`, `write`, or `owner` roles.
  - **Permission deletion** revokes the corresponding access grant. Owner
    permissions cannot be deleted.
  - Permissions may be inherited from parent items via the `inheritedFrom`
    field; inherited permissions must be removed at the parent level.
  """

  use ExUnit.Case, async: true

  @moduletag :live_smoke

  alias Jido.Connect.MicrosoftOnedrive.Handlers.Actions

  # ── Env guard ─────────────────────────────────────────────────────────

  defp access_token do
    System.get_env("MICROSOFT_ACCESS_TOKEN")
  end

  defp onedrive_drive_id do
    System.get_env("MICROSOFT_ONEDRIVE_DRIVE_ID")
  end

  defp onedrive_item_id do
    System.get_env("MICROSOFT_ONEDRIVE_ITEM_ID")
  end

  setup_all do
    token = access_token()

    if token && token != "" do
      {:ok, token: token}
    else
      {:skip, "MICROSOFT_ACCESS_TOKEN not set — skipping live smoke tests"}
    end
  end

  # ── Helper ────────────────────────────────────────────────────────────

  defp credentials(token) do
    %{credentials: %{access_token: token}}
  end

  # ── Read-only: List Items ─────────────────────────────────────────────

  describe "list items (live)" do
    test "returns a page of items for the authenticated user", %{token: token} do
      assert {:ok, %{items: items}} =
               Actions.ListItems.run(
                 %{page_size: 5},
                 credentials(token)
               )

      assert is_list(items)
    end
  end

  # ── Read-only: Get Drive ──────────────────────────────────────────────

  describe "get drive (live)" do
    test "returns default drive metadata for the authenticated user", %{token: token} do
      assert {:ok, %{drive: drive}} =
               Actions.GetDrive.run(%{}, credentials(token))

      assert is_map(drive)
      assert Map.has_key?(drive, :drive_id) or Map.has_key?(drive, :name)
    end
  end

  # ── Read-only: List Drives ────────────────────────────────────────────

  describe "list drives (live)" do
    test "returns a page of drives", %{token: token} do
      assert {:ok, %{drives: drives}} =
               Actions.ListDrives.run(
                 %{page_size: 5},
                 credentials(token)
               )

      assert is_list(drives)
    end

    test "fetches a specific drive when MICROSOFT_ONEDRIVE_DRIVE_ID is set", %{
      token: token
    } do
      drive_id = onedrive_drive_id()

      if drive_id && drive_id != "" do
        # GetDrive fetches the default drive; if a specific drive id is
        # available, list drives and verify it appears in the results.
        assert {:ok, %{drives: drives}} =
                 Actions.ListDrives.run(
                   %{page_size: 50},
                   credentials(token)
                 )

        ids = Enum.map(drives, &Map.get(&1, :drive_id))
        assert drive_id in ids
      end
    end
  end

  # ── Read-only: Search Items ───────────────────────────────────────────

  describe "search items (live)" do
    test "returns search results for a query", %{token: token} do
      assert {:ok, %{items: items}} =
               Actions.Search.run(
                 %{query: "test", page_size: 5},
                 credentials(token)
               )

      assert is_list(items)
    end
  end

  # ── Read-only: Get Item ───────────────────────────────────────────────

  describe "get item (live)" do
    test "fetches a specific item when MICROSOFT_ONEDRIVE_ITEM_ID is set", %{token: token} do
      item_id = onedrive_item_id()

      if item_id && item_id != "" do
        assert {:ok, %{item: item}} =
                 Actions.GetItem.run(
                   %{item_id: item_id},
                   credentials(token)
                 )

        assert is_map(item)
        assert Map.get(item, :item_id) == item_id
      end
    end
  end

  # ── Read-only: Delta ──────────────────────────────────────────────────

  describe "delta (live)" do
    test "returns an initial delta response", %{token: token} do
      assert {:ok, result} =
               Actions.Delta.run(%{}, credentials(token))

      assert is_list(Map.get(result, :items, []))

      # Initial sync should include a delta_link or delta_token
      assert Map.get(result, :delta_link) || Map.get(result, :delta_token)
    end
  end

  # ── Destructive: Create and Delete Item ───────────────────────────────

  describe "create and delete item (live, destructive)" do
    @tag :live_destructive
    test "creates a folder and then deletes it", %{token: token} do
      skip_unless_destructive!()

      assert {:ok, %{item: created}} =
               Actions.CreateItem.run(
                 %{
                   name: "smoke-test-folder-#{System.unique_integer([:positive])}",
                   type: "folder"
                 },
                 credentials(token)
               )

      assert created.item_id

      assert {:ok, %{deleted: true}} =
               Actions.DeleteItem.run(
                 %{item_id: created.item_id},
                 credentials(token)
               )
    end
  end

  # ── Destructive: Create Sharing Link and Delete Permission ────────────

  describe "create sharing link and delete permission (live, destructive)" do
    @tag :live_destructive
    test "creates a view link and revokes the permission", %{token: token} do
      skip_unless_destructive!()

      # First, find an item to share
      assert {:ok, %{items: [item | _]}} =
               Actions.ListItems.run(
                 %{page_size: 1},
                 credentials(token)
               )

      assert {:ok, %{permission: perm}} =
               Actions.CreateSharingLink.run(
                 %{item_id: item.item_id, type: "view"},
                 credentials(token)
               )

      assert perm.permission_id

      assert {:ok, %{deleted: true}} =
               Actions.DeletePermission.run(
                 %{item_id: item.item_id, permission_id: perm.permission_id},
                 credentials(token)
               )
    end
  end

  # ── Helper ────────────────────────────────────────────────────────────

  defp skip_unless_destructive! do
    unless System.get_env("MICROSOFT_LIVE_DESTRUCTIVE") == "true" do
      ExUnit.Assertions.flunk(
        "Set MICROSOFT_LIVE_DESTRUCTIVE=true to enable destructive live smoke tests."
      )
    end
  end
end
