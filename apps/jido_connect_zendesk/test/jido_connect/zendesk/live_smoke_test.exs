defmodule Jido.Connect.Zendesk.LiveSmokeTest do
  @moduledoc """
  Env-gated read-only live smoke hooks for Zendesk.

  These tests only run when the `ZENDESK_API_TOKEN` and `ZENDESK_SUBDOMAIN`
  environment variables are set. They exercise real API calls against the
  configured Zendesk subdomain in read-only mode.

  ## Running

      ZENDESK_SUBDOMAIN=example ZENDESK_API_TOKEN=xxx mix test .../live_smoke_test.exs

  These tests are excluded from default runs. Use `--include live_smoke`
  to opt in when credentials are available.

  ## Safety

  - All tests are read-only — no tickets are created, updated, or deleted.
  - No destructive or write actions are exercised.
  - Tokens, secrets, and credential material are never logged or exposed in
    test output.
  """

  use ExUnit.Case, async: true

  @moduletag :live_smoke

  # ── Env guard ─────────────────────────────────────────────────────────

  defp api_token do
    System.get_env("ZENDESK_API_TOKEN")
  end

  defp subdomain do
    System.get_env("ZENDESK_SUBDOMAIN")
  end

  defp email do
    System.get_env("ZENDESK_EMAIL")
  end

  defp skip_unless_env_set do
    unless env_configured?() do
      ExUnit.configure(exclude: [:live_smoke])
    end
  end

  defp env_configured? do
    api_token() != nil and api_token() != "" and
      subdomain() != nil and subdomain() != ""
  end

  setup_all do
    skip_unless_env_set()

    if env_configured?() do
      :ok
    else
      {:skip, "ZENDESK_API_TOKEN / ZENDESK_SUBDOMAIN not set — skipping live smoke tests"}
    end
  end

  # ── Helper ────────────────────────────────────────────────────────────

  defp credentials do
    base = %{
      credentials: %{
        api_key: api_token(),
        subdomain: subdomain()
      }
    }

    if email() && email() != "" do
      put_in(base, [:credentials, :email], email())
    else
      base
    end
  end

  # ── List tickets (read-only) ──────────────────────────────────────────

  describe "list tickets (live)" do
    test "returns a page of tickets" do
      assert {:ok, result} =
               Jido.Connect.Zendesk.Handlers.Actions.ListTickets.run(
                 %{per_page: 5},
                 credentials()
               )

      assert is_list(result.items)

      for ticket <- result.items do
        assert Map.has_key?(ticket, :id)
      end
    end
  end

  # ── Search tickets (read-only) ────────────────────────────────────────

  describe "search tickets (live)" do
    test "returns search results" do
      assert {:ok, result} =
               Jido.Connect.Zendesk.Handlers.Actions.SearchTickets.run(
                 %{query: "status:open", per_page: 5},
                 credentials()
               )

      assert is_list(result.items)
    end
  end

  # ── Get ticket (read-only) ────────────────────────────────────────────

  describe "get ticket (live)" do
    test "fetches a single ticket when ZENDESK_TICKET_ID is set" do
      ticket_id = System.get_env("ZENDESK_TICKET_ID")

      if ticket_id && ticket_id != "" do
        assert {:ok, ticket} =
                 Jido.Connect.Zendesk.Handlers.Actions.GetTicket.run(
                   %{ticket_id: String.to_integer(ticket_id)},
                   credentials()
                 )

        assert ticket.id == String.to_integer(ticket_id)
      end
    end
  end

  # ── List users (read-only) ────────────────────────────────────────────

  describe "list users (live)" do
    test "returns a page of users" do
      assert {:ok, result} =
               Jido.Connect.Zendesk.Handlers.Actions.ListUsers.run(
                 %{per_page: 5},
                 credentials()
               )

      assert is_list(result.items)

      for user <- result.items do
        assert Map.has_key?(user, :id)
      end
    end
  end

  # ── Webhook verification (offline, live secret) ───────────────────────

  describe "webhook signature verification" do
    test "verifies a computed signature round-trip" do
      secret = System.get_env("ZENDESK_WEBHOOK_SECRET") || "test-secret"

      body = ~s({"type":"Ticket Created","ticket":{"id":1}})
      computed = Jido.Connect.Zendesk.Webhook.compute_signature(body, secret)

      assert :ok = Jido.Connect.Zendesk.Webhook.verify_signature(computed, computed)
    end
  end
end
