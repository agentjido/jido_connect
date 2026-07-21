defmodule Jido.Connect.PostHog.FixtureTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.PostHog.Client.Normalizer

  describe "event fixtures" do
    test "normalizes common event fixture" do
      payload = fixture!("event_common.json")

      assert {:ok, event} = Normalizer.event(payload)
      assert event.id == "event-001"
      assert event.event == "pageview"
      assert event.distinct_id == "user-1"
      assert event.properties["path"] == "/home"
      assert event.properties["referrer"] == "https://google.com"
      assert event.properties["browser"] == "Chrome"
      assert event.timestamp == "2026-05-15T10:00:00.000Z"
    end

    test "normalizes events list fixture" do
      payload = fixture!("events_list.json")

      results = payload["results"]
      assert length(results) == 2

      assert {:ok, first} = Normalizer.event(Enum.at(results, 0))
      assert first.id == "event-001"
      assert first.event == "pageview"
      assert first.distinct_id == "user-1"

      assert {:ok, second} = Normalizer.event(Enum.at(results, 1))
      assert second.id == "event-002"
      assert second.event == "signup"
      assert second.properties["plan"] == "pro"

      assert {:ok, page} = Normalizer.pagination(payload)
      assert page.next == nil
      assert page.count == 2
    end
  end

  describe "person fixtures" do
    test "normalizes common person fixture" do
      payload = fixture!("person_common.json")

      assert {:ok, person} = Normalizer.person(payload)
      assert person.id == "person-001"
      assert person.distinct_ids == ["user-1", "alias-abc123"]
      assert person.name == "Alice Nakamura"
      assert person.email == "alice@example.com"
      assert person.properties["plan"] == "pro"
      assert person.created_at == "2026-05-01T00:00:00.000Z"
    end

    test "normalizes persons list fixture" do
      payload = fixture!("persons_list.json")

      results = payload["results"]
      assert length(results) == 2

      assert {:ok, first} = Normalizer.person(Enum.at(results, 0))
      assert first.id == "person-001"
      assert first.name == "Alice Nakamura"

      assert {:ok, second} = Normalizer.person(Enum.at(results, 1))
      assert second.id == "person-002"
      assert second.name == "Bob Martinez"

      assert {:ok, page} = Normalizer.pagination(payload)
      assert page.next == "https://app.posthog.com/api/projects/1/persons/?offset=100"
      assert page.count == 142
    end
  end

  describe "feature flag fixtures" do
    test "normalizes common feature flag fixture" do
      payload = fixture!("feature_flag_common.json")

      assert {:ok, flag} = Normalizer.feature_flag(payload)
      assert flag.id == "42"
      assert flag.key == "new-dashboard"
      assert flag.name == "New Dashboard"
      assert flag.description == "Enable the redesigned dashboard experience for selected users."
      assert flag.active == true
      assert flag.rollout_percentage == 50.0
      assert flag.filters["groups"] != nil
      assert flag.created_at == "2026-04-20T09:00:00.000Z"
    end

    test "normalizes feature flag filters with conditions" do
      payload = fixture!("feature_flag_common.json")

      assert {:ok, flag} = Normalizer.feature_flag(payload)
      [group | _] = flag.filters["groups"]
      [prop | _] = group["properties"]
      assert prop["key"] == "plan"
      assert prop["operator"] == "exact"
      assert prop["value"] == ["pro", "enterprise"]
    end
  end

  describe "flag evaluation fixtures" do
    test "normalizes common flag evaluation fixture" do
      payload = fixture!("flag_evaluation_common.json")

      assert {:ok, eval} = Normalizer.flag_evaluation(payload)
      assert eval.flag_key == "new-dashboard"
      assert eval.enabled == true
      assert eval.variant == "variant-a"
      assert eval.reason == "matched_condition"
      assert eval.payload["color_scheme"] == "dark"
      assert eval.payload["layout"] == "grid"
    end
  end

  describe "insight fixtures" do
    test "normalizes common insight fixture" do
      payload = fixture!("insight_common.json")

      assert {:ok, insight} = Normalizer.insight(payload)
      assert insight.id == "insight-001"
      assert insight.short_id == "iNbXkq2a"
      assert insight.name == "Pageviews over time"
      assert insight.derived_name == "Pageviews over time"
      assert insight.type == "InsightLineChart"
      assert insight.description == "Trend of pageview events over the last 30 days."
      assert insight.created_at == "2026-05-01T00:00:00.000Z"
      assert insight.updated_at == "2026-05-15T00:00:00.000Z"
    end

    test "normalizes insight result data" do
      payload = fixture!("insight_common.json")

      assert {:ok, insight} = Normalizer.insight(payload)
      [data_point | _] = insight.result
      assert data_point["data"] == [120, 145, 130, 180, 210, 195, 220]
      assert length(data_point["labels"]) == 7
    end

    test "normalizes insights list fixture" do
      payload = fixture!("insights_list.json")

      results = payload["results"]
      assert length(results) == 2

      assert {:ok, first} = Normalizer.insight(Enum.at(results, 0))
      assert first.id == "insight-001"
      assert first.type == "InsightLineChart"

      assert {:ok, second} = Normalizer.insight(Enum.at(results, 1))
      assert second.id == "insight-002"
      assert second.type == "InsightFunnel"
      assert second.description == "Conversion funnel from landing page to signup completion."

      assert {:ok, page} = Normalizer.pagination(payload)
      assert page.next == nil
      assert page.count == 2
    end
  end

  describe "query result fixtures" do
    test "normalizes common query result fixture" do
      payload = fixture!("query_result_common.json")

      assert {:ok, result} = Normalizer.query_result(payload)
      assert result.query =~ "SELECT event, count() FROM events"
      assert result.columns == ["event", "count()"]
      assert length(result.results) == 5
      assert Enum.at(result.results, 0)["event"] == "pageview"
      assert Enum.at(result.results, 0)["count()"] == 15420
      assert Enum.at(result.results, 4)["event"] == "feature_used"
      assert result.has_more == false
    end
  end

  describe "pagination fixtures" do
    test "normalizes common pagination fixture" do
      payload = fixture!("pagination_common.json")

      assert {:ok, page} = Normalizer.pagination(payload)
      assert page.next == "https://app.posthog.com/api/projects/1/events/?offset=100"
      assert page.previous == nil
      assert page.count == 250
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "test", "fixtures", "posthog", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
