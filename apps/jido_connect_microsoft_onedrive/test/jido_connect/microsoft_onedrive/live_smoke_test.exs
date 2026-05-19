defmodule Jido.Connect.MicrosoftOnedrive.LiveSmokeTest do
  @moduledoc """
  Env-gated read-only live smoke hooks for Microsoft OneDrive.

  These tests only run when the `MICROSOFT_ACCESS_TOKEN` environment variable
  is set to a valid Microsoft Graph OAuth token with Files.Read scope.
  They exercise real API calls against the authenticated user's OneDrive in
  read-only mode.

  ## Running

      MICROSOFT_ACCESS_TOKEN="eyJ..." mix test .../live_smoke_test.exs --include live_smoke

  These tests are excluded from default runs. Use `--include live_smoke`
  to opt in when credentials are available.

  ## Safety

  - All tests are read-only — no files are created, updated, or deleted.
  - No destructive or write actions are exercised.
  - Tokens, secrets, and credential material are never logged or exposed in
    test output.

  ## Note

  Handler implementations are pending. These tests will be activated once
  the read handlers are implemented in a follow-up task.
  """

  use ExUnit.Case, async: true

  @moduletag :live_smoke

  setup_all do
    token = System.get_env("MICROSOFT_ACCESS_TOKEN")

    if token && token != "" do
      :ok
    else
      {:skip, "MICROSOFT_ACCESS_TOKEN not set — skipping live smoke tests"}
    end
  end

  describe "list items (live)" do
    @tag :skip
    test "returns a page of items for the authenticated user" do
      assert {:ok, %{items: items}} =
               Jido.Connect.MicrosoftOnedrive.Handlers.Actions.ListItems.run(
                 %{page_size: 5},
                 %{credentials: %{access_token: System.get_env("MICROSOFT_ACCESS_TOKEN")}}
               )

      assert is_list(items)
    end
  end
end
