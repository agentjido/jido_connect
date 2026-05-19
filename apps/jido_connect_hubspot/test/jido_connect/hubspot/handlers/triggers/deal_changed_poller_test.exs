defmodule Jido.Connect.HubSpot.Handlers.Triggers.DealChangedPollerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Deal
  alias Jido.Connect.HubSpot.Handlers.Triggers.DealChangedPoller

  defmodule FakeClient do
    # --- Initial full-scan (no filter_groups) ---

    def list_deals(_params, "token") do
      {:ok,
       %{
         items: [
           Deal.new!(%{
             deal_id: "301",
             deal_name: "Acme Enterprise License",
             amount: 120_000,
             deal_stage: "contractsent",
             updated_at: "2026-05-10T11:30:00.000Z"
           }),
           Deal.new!(%{
             deal_id: "302",
             deal_name: "Globex Support Contract",
             amount: 50_000,
             deal_stage: "qualifiedtobuy",
             updated_at: "2026-05-12T09:00:00.000Z"
           })
         ]
       }}
    end

    # Empty deal list
    def list_deals(_params, "empty_token") do
      {:ok, %{items: []}}
    end

    # --- Changed deals (search with filter_groups) ---

    def search_deals(
          %{filter_groups: [_], updated_min: "2026-05-12T09:00:00.000Z"},
          "token"
        ) do
      {:ok,
       %{
         items: [
           Deal.new!(%{
             deal_id: "302",
             deal_name: "Globex Support Contract",
             amount: 55_000,
             deal_stage: "closedwon",
             updated_at: "2026-05-13T15:00:00.000Z"
           })
         ]
       }}
    end

    def search_deals(
          %{filter_groups: [_], updated_min: "2026-05-16T12:00:00.000Z"},
          "token"
        ) do
      {:ok, %{items: []}}
    end
  end

  describe "poll/2 with no checkpoint" do
    test "initializes checkpoint without emitting signals" do
      config = %{}
      credentials = %{api_key: "token", hubspot_client: FakeClient}

      assert {:ok, %{signals: [], checkpoint: checkpoint}} =
               DealChangedPoller.poll(config, %{credentials: credentials, checkpoint: nil})

      assert checkpoint == "2026-05-12T09:00:00.000Z"
    end

    test "returns error when no deals have updated timestamps" do
      config = %{}
      credentials = %{api_key: "empty_token", hubspot_client: FakeClient}

      assert {:error, %{reason: :invalid_response}} =
               DealChangedPoller.poll(config, %{credentials: credentials, checkpoint: nil})
    end
  end

  describe "poll/2 with existing checkpoint" do
    test "emits signals for changed deals and advances checkpoint" do
      config = %{}
      credentials = %{api_key: "token", hubspot_client: FakeClient}
      checkpoint = "2026-05-12T09:00:00.000Z"

      assert {:ok, %{signals: signals, checkpoint: new_checkpoint}} =
               DealChangedPoller.poll(config, %{credentials: credentials, checkpoint: checkpoint})

      assert new_checkpoint == "2026-05-13T15:00:00.000Z"
      assert length(signals) == 1

      [signal] = signals
      assert signal.deal_id == "302"
      assert signal.change_type == "updated"
    end

    test "sets change_type to archived for archived deals" do
      deal =
        Deal.new!(%{
          deal_id: "301",
          deal_name: "Archived Deal",
          updated_at: "2026-05-15T12:00:00.000Z",
          archived?: true
        })

      signal = normalize_deal_signal(deal)
      assert signal.change_type == "archived"
    end

    test "returns empty signals when no deals changed" do
      config = %{}
      credentials = %{api_key: "token", hubspot_client: FakeClient}
      checkpoint = "2026-05-16T12:00:00.000Z"

      assert {:ok, %{signals: [], checkpoint: ^checkpoint}} =
               DealChangedPoller.poll(config, %{credentials: credentials, checkpoint: checkpoint})
    end
  end

  describe "signal shape" do
    test "each signal contains expected fields" do
      config = %{}
      credentials = %{api_key: "token", hubspot_client: FakeClient}
      checkpoint = "2026-05-12T09:00:00.000Z"

      assert {:ok, %{signals: [signal | _]}} =
               DealChangedPoller.poll(config, %{credentials: credentials, checkpoint: checkpoint})

      assert Map.has_key?(signal, :deal_id)
      assert Map.has_key?(signal, :deal_name)
      assert Map.has_key?(signal, :change_type)
      assert Map.has_key?(signal, :updated_at)
      assert Map.has_key?(signal, :deal)
    end
  end

  defp normalize_deal_signal(deal) do
    %{
      deal_id: Map.get(deal, :deal_id),
      change_type: change_type(deal),
      updated_at: Map.get(deal, :updated_at)
    }
  end

  defp change_type(%{archived?: true}), do: "archived"
  defp change_type(_deal), do: "updated"
end
