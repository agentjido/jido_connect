defmodule Jido.Connect.PostHog.Handlers.Actions.GetInsightTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.PostHog.Handlers.Actions.GetInsight

  describe "run/2" do
    test "fetches a single insight by ID with normalized result" do
      credentials = %{posthog_client: Jido.Connect.PostHog.MockClient, api_key: "token"}

      input = %{insight_id: "insight-001"}

      assert {:ok, result} = GetInsight.run(input, %{credentials: credentials})
      assert result.id == "insight-001"
      assert result.short_id == "iNbXkq2a"
      assert result.name == "Pageviews"
      assert result.derived_name == "Pageviews over time"
      assert result.type == "InsightLineChart"
      assert result.created_at == "2026-05-01T00:00:00.000Z"
      assert result.updated_at == "2026-05-15T00:00:00.000Z"
    end

    test "passes date range options" do
      credentials = %{posthog_client: Jido.Connect.PostHog.MockClient, api_key: "token"}

      input = %{insight_id: "insight-001", date_from: "-7d", date_to: "2026-05-15"}

      assert {:ok, result} = GetInsight.run(input, %{credentials: credentials})
      assert result.id == "insight-001"
    end

    test "returns error on API failure" do
      credentials = %{posthog_client: Jido.Connect.PostHog.ErrorGetInsightMock, api_key: "token"}

      input = %{insight_id: "nonexistent"}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :posthog}} =
               GetInsight.run(input, %{credentials: credentials})
    end
  end
end

defmodule Jido.Connect.PostHog.ErrorGetInsightMock do
  @moduledoc false

  def get_insight("nonexistent", "token", _opts) do
    {:ok, %Req.Response{status: 404, body: %{"detail" => "Not found."}}}
  end
end
