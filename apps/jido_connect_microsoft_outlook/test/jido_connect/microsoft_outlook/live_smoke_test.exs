defmodule Jido.Connect.MicrosoftOutlook.LiveSmokeTest do
  @moduledoc """
  Env-gated read-only live smoke hooks for Outlook Mail.

  These tests only run when the `MICROSOFT_ACCESS_TOKEN` environment variable
  is set to a valid Microsoft Graph OAuth token with Mail.Read and
  MailboxSettings.Read scopes. They exercise real API calls against the
  authenticated user's mailbox in read-only mode.

  ## Running

      MICROSOFT_ACCESS_TOKEN="eyJ..." mix test .../live_smoke_test.exs

  These tests are excluded from default runs. Use `--include live_smoke`
  to opt in when credentials are available.

  ## Safety

  - All tests are read-only — no messages are created, sent, moved, or deleted.
  - No destructive or write actions are exercised.
  - Tokens, secrets, and credential material are never logged or exposed in
    test output.
  """

  use ExUnit.Case, async: true

  @moduletag :live_smoke

  # ── Env guard ─────────────────────────────────────────────────────────

  defp access_token do
    System.get_env("MICROSOFT_ACCESS_TOKEN")
  end

  defp outlook_message_id do
    System.get_env("MICROSOFT_OUTLOOK_MESSAGE_ID")
  end

  defp skip_unless_env_set do
    unless access_token() != nil and access_token() != "" do
      ExUnit.configure(exclude: [:live_smoke])
    end
  end

  setup_all do
    skip_unless_env_set()

    if access_token() do
      :ok
    else
      {:skip, "MICROSOFT_ACCESS_TOKEN not set — skipping live smoke tests"}
    end
  end

  # ── Helper ────────────────────────────────────────────────────────────

  defp credentials do
    %{credentials: %{access_token: access_token()}}
  end

  # ── Profile ───────────────────────────────────────────────────────────

  describe "get profile (live)" do
    test "returns authenticated user profile metadata" do
      assert {:ok, %{profile: profile}} =
               Jido.Connect.MicrosoftOutlook.Handlers.Actions.GetProfile.run(%{}, credentials())

      assert is_map(profile)
      assert Map.has_key?(profile, :user_id) or Map.has_key?(profile, :display_name)
    end
  end

  # ── Folders ───────────────────────────────────────────────────────────

  describe "list folders (live)" do
    test "returns a page of mail folders" do
      assert {:ok, %{folders: folders}} =
               Jido.Connect.MicrosoftOutlook.Handlers.Actions.ListFolders.run(
                 %{},
                 credentials()
               )

      assert is_list(folders)
      assert length(folders) > 0

      for folder <- folders do
        assert Map.has_key?(folder, :folder_id)
        assert Map.has_key?(folder, :display_name)
      end
    end
  end

  # ── Messages ──────────────────────────────────────────────────────────

  describe "list messages (live)" do
    test "returns a page of inbox messages" do
      assert {:ok, %{messages: messages}} =
               Jido.Connect.MicrosoftOutlook.Handlers.Actions.ListMessages.run(
                 %{folder_id: "inbox", page_size: 5},
                 credentials()
               )

      assert is_list(messages)

      for msg <- messages do
        assert Map.has_key?(msg, :message_id)
        # Body content must not leak in listing
        refute Map.has_key?(msg, :content)
      end
    end
  end

  describe "get message (live)" do
    test "fetches a single message when MICROSOFT_OUTLOOK_MESSAGE_ID is set" do
      message_id = outlook_message_id()

      if message_id && message_id != "" do
        assert {:ok, %{message: msg}} =
                 Jido.Connect.MicrosoftOutlook.Handlers.Actions.GetMessage.run(
                   %{message_id: message_id},
                   credentials()
                 )

        assert msg.message_id == message_id
        assert is_map(msg.body_summary)
        # Body content must not leak
        refute Map.has_key?(msg.body_summary, :content)
      end
    end
  end
end
