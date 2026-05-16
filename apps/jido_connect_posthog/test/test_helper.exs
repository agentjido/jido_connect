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
end

# Ensure Req.Test.Ownership is running so that client tests using
# `setup {Req.Test, :verify_on_exit!}` work even when the umbrella
# cannot start the full application supervision tree.
unless Process.whereis(Req.Test.Ownership) do
  {:ok, _} = Req.Test.Ownership.start_link(name: Req.Test.Ownership)
end
