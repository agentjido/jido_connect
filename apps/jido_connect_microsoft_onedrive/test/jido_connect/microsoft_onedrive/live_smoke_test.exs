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

  - Read-only tests run without gating.
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

  setup_all do
    token = System.get_env("MICROSOFT_ACCESS_TOKEN")

    if token && token != "" do
      {:ok, token: token}
    else
      {:skip, "MICROSOFT_ACCESS_TOKEN not set — skipping live smoke tests"}
    end
  end

  describe "list items (live)" do
    @tag :skip
    test "returns a page of items for the authenticated user", %{token: token} do
      assert {:ok, %{items: items}} =
               Jido.Connect.MicrosoftOnedrive.Handlers.Actions.ListItems.run(
                 %{page_size: 5},
                 %{credentials: %{access_token: token}}
               )

      assert is_list(items)
    end
  end

  describe "create and delete item (live, destructive)" do
    @tag :skip
    @tag :live_destructive
    test "creates a folder and then deletes it", %{token: token} do
      skip_unless_destructive!()

      assert {:ok, %{item: created}} =
               Jido.Connect.MicrosoftOnedrive.Handlers.Actions.CreateItem.run(
                 %{
                   name: "smoke-test-folder-#{System.unique_integer([:positive])}",
                   type: "folder"
                 },
                 %{credentials: %{access_token: token}}
               )

      assert created.item_id

      assert {:ok, %{deleted: true}} =
               Jido.Connect.MicrosoftOnedrive.Handlers.Actions.DeleteItem.run(
                 %{item_id: created.item_id},
                 %{credentials: %{access_token: token}}
               )
    end
  end

  describe "create sharing link and delete permission (live, destructive)" do
    @tag :skip
    @tag :live_destructive
    test "creates a view link and revokes the permission", %{token: token} do
      skip_unless_destructive!()

      # First, find an item to share
      assert {:ok, %{items: [item | _]}} =
               Jido.Connect.MicrosoftOnedrive.Handlers.Actions.ListItems.run(
                 %{page_size: 1},
                 %{credentials: %{access_token: token}}
               )

      assert {:ok, %{permission: perm}} =
               Jido.Connect.MicrosoftOnedrive.Handlers.Actions.CreateSharingLink.run(
                 %{item_id: item.item_id, type: "view"},
                 %{credentials: %{access_token: token}}
               )

      assert perm.permission_id

      assert {:ok, %{deleted: true}} =
               Jido.Connect.MicrosoftOnedrive.Handlers.Actions.DeletePermission.run(
                 %{item_id: item.item_id, permission_id: perm.permission_id},
                 %{credentials: %{access_token: token}}
               )
    end
  end

  defp skip_unless_destructive! do
    unless System.get_env("MICROSOFT_LIVE_DESTRUCTIVE") == "true" do
      ExUnit.Assertions.flunk(
        "Set MICROSOFT_LIVE_DESTRUCTIVE=true to enable destructive live smoke tests."
      )
    end
  end
end
