defmodule Jido.Connect.PostHog.Handlers.Actions.RunQueryTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.PostHog.Handlers.Actions.RunQuery

  describe "run/2" do
    test "executes a HogQL query with normalized results" do
      credentials = %{posthog_client: Jido.Connect.PostHog.MockClient, api_key: "token"}

      input = %{query: "SELECT event, count() FROM events GROUP BY event LIMIT 5"}

      assert {:ok, result} = RunQuery.run(input, %{credentials: credentials})
      assert result.query == "SELECT event, count() FROM events GROUP BY event LIMIT 5"
      assert result.columns == ["event", "count()"]
      assert length(result.results) == 3
      assert Enum.at(result.results, 0)["event"] == "pageview"
      assert Enum.at(result.results, 0)["count()"] == 15420
      assert result.has_more == false
    end

    test "executes a query with date range options" do
      credentials = %{posthog_client: Jido.Connect.PostHog.MockClient, api_key: "token"}

      input = %{
        query: "SELECT event, count() FROM events GROUP BY event LIMIT 5",
        date_from: "2026-05-01",
        date_to: "2026-05-15"
      }

      assert {:ok, result} = RunQuery.run(input, %{credentials: credentials})
      assert result.columns == ["event", "count()"]
    end

    test "executes a query with relative date range" do
      credentials = %{posthog_client: Jido.Connect.PostHog.MockClient, api_key: "token"}

      input = %{
        query: "SELECT event, count() FROM events GROUP BY event LIMIT 5",
        date_from: "-30d",
        date_to: "-1d"
      }

      assert {:ok, result} = RunQuery.run(input, %{credentials: credentials})
      assert is_list(result.columns)
    end

    test "returns error on API failure" do
      credentials = %{posthog_client: Jido.Connect.PostHog.ErrorQueryMock, api_key: "token"}

      input = %{query: "INVALID QUERY"}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :posthog}} =
               RunQuery.run(input, %{credentials: credentials})
    end
  end
end

defmodule Jido.Connect.PostHog.ErrorQueryMock do
  @moduledoc false

  def run_query("token", "INVALID QUERY", _opts) do
    {:ok, %Req.Response{status: 400, body: %{"detail" => "Invalid HogQL query."}}}
  end
end
