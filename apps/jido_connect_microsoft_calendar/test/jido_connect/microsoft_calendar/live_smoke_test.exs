defmodule Jido.Connect.MicrosoftCalendar.LiveSmokeTest do
  @moduledoc """
  Env-gated read-only live smoke hooks for Microsoft Calendar.

  These tests only run when the `MICROSOFT_ACCESS_TOKEN` environment variable
  is set to a valid Microsoft Graph OAuth token with Calendars.Read scope.
  They exercise real API calls against the authenticated user's calendar in
  read-only mode.

  ## Running

      MICROSOFT_ACCESS_TOKEN="eyJ..." mix test .../live_smoke_test.exs --include live_smoke

  These tests are excluded from default runs. Use `--include live_smoke`
  to opt in when credentials are available.

  ## Fixture IDs

  Optional fixture ids allow detail smoke tests:

  - `MICROSOFT_CALENDAR_ID` — a known calendar id for get-calendar tests.
  - `MICROSOFT_EVENT_ID` — a known event id for get-event tests.

  ## Safety

  - All tests are read-only — no events are created, updated, or deleted.
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

  defp calendar_id do
    System.get_env("MICROSOFT_CALENDAR_ID")
  end

  defp event_id do
    System.get_env("MICROSOFT_EVENT_ID")
  end

  setup_all do
    if access_token() && access_token() != "" do
      :ok
    else
      {:skip, "MICROSOFT_ACCESS_TOKEN not set — skipping live smoke tests"}
    end
  end

  # ── Helper ────────────────────────────────────────────────────────────

  defp credentials do
    %{credentials: %{access_token: access_token()}}
  end

  # ── Calendars ─────────────────────────────────────────────────────────

  describe "list calendars (live)" do
    test "returns a page of calendars for the authenticated user" do
      assert {:ok, %{calendars: calendars}} =
               Jido.Connect.MicrosoftCalendar.Handlers.Actions.ListCalendars.run(
                 %{page_size: 5},
                 credentials()
               )

      assert is_list(calendars)

      for cal <- calendars do
        assert Map.has_key?(cal, :calendar_id)
        assert Map.has_key?(cal, :name)
      end
    end
  end

  describe "get calendar (live)" do
    test "fetches a single calendar when MICROSOFT_CALENDAR_ID is set" do
      id = calendar_id()

      if id && id != "" do
        assert {:ok, %{calendar: cal}} =
                 Jido.Connect.MicrosoftCalendar.Handlers.Actions.GetCalendar.run(
                   %{calendar_id: id},
                   credentials()
                 )

        assert Map.has_key?(cal, :calendar_id)
        assert Map.has_key?(cal, :name)
      end
    end
  end

  # ── Events ────────────────────────────────────────────────────────────

  describe "list events (live)" do
    test "returns a page of events for the default calendar" do
      assert {:ok, %{events: events}} =
               Jido.Connect.MicrosoftCalendar.Handlers.Actions.ListEvents.run(
                 %{page_size: 5},
                 credentials()
               )

      assert is_list(events)

      for ev <- events do
        assert Map.has_key?(ev, :event_id)
        # Body content must not leak in listing
        refute Map.has_key?(ev, :content)
      end
    end
  end

  describe "get event (live)" do
    test "fetches a single event when MICROSOFT_EVENT_ID is set" do
      id = event_id()

      if id && id != "" do
        assert {:ok, %{event: ev}} =
                 Jido.Connect.MicrosoftCalendar.Handlers.Actions.GetEvent.run(
                   %{event_id: id},
                   credentials()
                 )

        assert Map.has_key?(ev, :event_id)
        assert is_map(ev.body_summary)
        # Body content must not leak
        refute Map.has_key?(ev.body_summary, :content)
      end
    end
  end

  # ── Schedule / Free-Busy ──────────────────────────────────────────────

  describe "get schedule (live)" do
    test "returns free/busy availability for the authenticated user" do
      start_dt = DateTime.utc_now() |> DateTime.to_iso8601()
      end_dt = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.to_iso8601()

      assert {:ok, %{results: results}} =
               Jido.Connect.MicrosoftCalendar.Handlers.Actions.GetSchedule.run(
                 %{
                   schedules: ["me"],
                   start_date_time: start_dt,
                   end_date_time: end_dt
                 },
                 credentials()
               )

      assert is_list(results)
    end
  end
end
