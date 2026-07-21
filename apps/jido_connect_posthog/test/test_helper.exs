ExUnit.start()

defmodule Jido.Connect.PostHog.MockClient do
  @moduledoc false

  def list_events("token", _opts) do
    {:ok,
     %Req.Response{
       status: 200,
       body: %{
         "results" => [
           %{
             "id" => "event-001",
             "event" => "pageview",
             "distinct_id" => "user-1",
             "properties" => %{"path" => "/home"},
             "timestamp" => "2026-05-15T10:00:00.000Z"
           }
         ],
         "next" => nil
       }
     }}
  end

  def get_event("event-001", "token") do
    {:ok,
     %Req.Response{
       status: 200,
       body: %{
         "id" => "event-001",
         "event" => "pageview",
         "distinct_id" => "user-1",
         "properties" => %{"path" => "/home"},
         "timestamp" => "2026-05-15T10:00:00.000Z"
       }
     }}
  end

  def list_persons("token", _opts) do
    {:ok,
     %Req.Response{
       status: 200,
       body: %{
         "results" => [
           %{
             "id" => "person-001",
             "distinct_ids" => ["user-1"],
             "properties" => %{"email" => "test@example.com"},
             "created_at" => "2026-05-01T00:00:00.000Z"
           }
         ],
         "next" => nil
       }
     }}
  end

  def get_person("user-1", "token") do
    {:ok,
     %Req.Response{
       status: 200,
       body: %{
         "id" => "person-001",
         "distinct_ids" => ["user-1"],
         "properties" => %{"email" => "test@example.com"},
         "created_at" => "2026-05-01T00:00:00.000Z"
       }
     }}
  end

  def list_insights("token", _opts) do
    {:ok,
     %Req.Response{
       status: 200,
       body: %{
         "results" => [
           %{
             "id" => "insight-001",
             "short_id" => "iNbXkq2a",
             "name" => "Pageviews",
             "derived_name" => "Pageviews over time",
             "kind" => "InsightLineChart",
             "result" => [%{"data" => [1, 2, 3]}],
             "created_at" => "2026-05-01T00:00:00.000Z",
             "updated_at" => "2026-05-15T00:00:00.000Z"
           }
         ],
         "next" => nil
       }
     }}
  end

  def get_insight("insight-001", "token") do
    {:ok,
     %Req.Response{
       status: 200,
       body: %{
         "id" => "insight-001",
         "short_id" => "iNbXkq2a",
         "name" => "Pageviews",
         "derived_name" => "Pageviews over time",
         "kind" => "InsightLineChart",
         "result" => [%{"data" => [1, 2, 3]}],
         "created_at" => "2026-05-01T00:00:00.000Z",
         "updated_at" => "2026-05-15T00:00:00.000Z"
       }
     }}
  end

  def get_insight("insight-001", "token", _opts) do
    {:ok,
     %Req.Response{
       status: 200,
       body: %{
         "id" => "insight-001",
         "short_id" => "iNbXkq2a",
         "name" => "Pageviews",
         "derived_name" => "Pageviews over time",
         "kind" => "InsightLineChart",
         "result" => [%{"data" => [1, 2, 3]}],
         "created_at" => "2026-05-01T00:00:00.000Z",
         "updated_at" => "2026-05-15T00:00:00.000Z"
       }
     }}
  end

  # HogQL query

  def run_query("token", "SELECT event, count() FROM events GROUP BY event LIMIT 5", _opts) do
    {:ok,
     %Req.Response{
       status: 200,
       body: %{
         "columns" => ["event", "count()"],
         "results" => [
           %{"event" => "pageview", "count()" => 15420},
           %{"event" => "signup", "count()" => 832},
           %{"event" => "purchase", "count()" => 215}
         ],
         "has_more" => false
       }
     }}
  end

  def run_query("token", _query, _opts) do
    {:ok,
     %Req.Response{
       status: 200,
       body: %{
         "columns" => ["event"],
         "results" => [],
         "has_more" => false
       }
     }}
  end

  # Event capture

  def capture_event("token", "pageview", "user-1", _opts) do
    {:ok, %Req.Response{status: 202, body: %{}}}
  end

  def batch_capture_events("token", events), do: batch_capture_events("token", events, [])

  def batch_capture_events("token", _events, _opts) do
    {:ok, %Req.Response{status: 202, body: %{}}}
  end

  # Feature flags

  def decide_feature_flag("new-dashboard", "user-1", "token", _opts) do
    {:ok,
     %Req.Response{
       status: 200,
       body: %{
         "featureFlags" => %{"new-dashboard" => true},
         "featureFlagPayloads" => %{},
         "reason" => nil
       }
     }}
  end

  def decide_feature_flag("dark-mode", "user-1", "token", _opts) do
    {:ok,
     %Req.Response{
       status: 200,
       body: %{
         "featureFlags" => %{"dark-mode" => "variant-a"},
         "featureFlagPayloads" => %{"dark-mode" => %{"color_scheme" => "dark"}},
         "reason" => nil
       }
     }}
  end

  def decide_feature_flag("disabled-flag", "user-1", "token", _opts) do
    {:ok,
     %Req.Response{
       status: 200,
       body: %{
         "featureFlags" => %{"disabled-flag" => false},
         "featureFlagPayloads" => %{},
         "reason" => nil
       }
     }}
  end

  def list_feature_flags("token", _opts) do
    {:ok,
     %Req.Response{
       status: 200,
       body: %{
         "results" => [
           %{
             "id" => 42,
             "key" => "new-dashboard",
             "name" => "New Dashboard",
             "description" => "Enable the redesigned dashboard experience.",
             "active" => true,
             "rollout_percentage" => 50.0,
             "filters" => %{},
             "created_at" => "2026-04-20T09:00:00.000Z"
           },
           %{
             "id" => 43,
             "key" => "dark-mode",
             "name" => "Dark Mode",
             "description" => "Enable dark mode UI theme.",
             "active" => true,
             "rollout_percentage" => 100.0,
             "filters" => %{},
             "created_at" => "2026-04-22T14:30:00.000Z"
           }
         ],
         "next" => nil
       }
     }}
  end

  def get_feature_flag("42", "token") do
    {:ok,
     %Req.Response{
       status: 200,
       body: %{
         "id" => 42,
         "key" => "new-dashboard",
         "name" => "New Dashboard",
         "description" => "Enable the redesigned dashboard experience for selected users.",
         "active" => true,
         "rollout_percentage" => 50.0,
         "filters" => %{"groups" => []},
         "created_at" => "2026-04-20T09:00:00.000Z"
       }
     }}
  end
end

# Ensure Req.Test.Ownership is running so that client tests using
# `setup {Req.Test, :verify_on_exit!}` work even when the umbrella
# cannot start the full application supervision tree.
unless Process.whereis(Req.Test.Ownership) do
  {:ok, _} = Req.Test.Ownership.start_link(name: Req.Test.Ownership)
end
