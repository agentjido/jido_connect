defmodule Jido.Connect.PostHog.Handlers.Actions.ListInsightsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.PostHog.Handlers.Actions.ListInsights

  describe "run/2" do
    test "lists insights with normalized results" do
      credentials = %{posthog_client: Jido.Connect.PostHog.MockClient, api_key: "token"}

      input = %{limit: 100, offset: 0}

      assert {:ok, result} = ListInsights.run(input, %{credentials: credentials})
      assert is_list(result.insights)
      assert length(result.insights) == 1

      first = Enum.at(result.insights, 0)
      assert first.id == "insight-001"
      assert first.short_id == "iNbXkq2a"
      assert first.name == "Pageviews"
      assert first.type == "InsightLineChart"
      assert result.next == nil
    end

    test "passes limit and offset options" do
      credentials = %{posthog_client: Jido.Connect.PostHog.MockClient, api_key: "token"}

      input = %{limit: 10, offset: 5}

      assert {:ok, result} = ListInsights.run(input, %{credentials: credentials})
      assert is_list(result.insights)
    end

    test "passes date range options" do
      credentials = %{posthog_client: Jido.Connect.PostHog.MockClient, api_key: "token"}

      input = %{limit: 100, offset: 0, date_from: "-30d", date_to: "-1d"}

      assert {:ok, result} = ListInsights.run(input, %{credentials: credentials})
      assert is_list(result.insights)
    end

    test "returns error on API failure" do
      credentials = %{posthog_client: Jido.Connect.PostHog.ErrorMockClient, api_key: "token"}

      input = %{limit: 100, offset: 0}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :posthog}} =
               ListInsights.run(input, %{credentials: credentials})
    end
  end
end

defmodule Jido.Connect.PostHog.ErrorMockClient do
  @moduledoc false

  def list_insights("token", _opts) do
    {:ok, %Req.Response{status: 401, body: %{"detail" => "Invalid token."}}}
  end
end
