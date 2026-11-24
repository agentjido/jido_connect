defmodule Jido.Connect.Examples.StartHere.Fixture do
  @moduledoc false

  @updated_at "2026-01-01T00:00:00Z"

  def get_pull_request("example/widgets", 42, "fixture-github") do
    {:ok,
     %{
       number: 42,
       title: "Update the widgets",
       state: "open",
       draft: false,
       url: "https://github.com/example/widgets/pull/42",
       updated_at: @updated_at
     }}
  end

  def list_updated_pull_requests("example/widgets", checkpoint, "fixture-github") do
    {:ok, pr} = get_pull_request("example/widgets", 42, "fixture-github")
    {:ok, if(checkpoint == @updated_at, do: [], else: [pr])}
  end

  def get_conversation_info(%{channel: "C-REVIEW"}, "fixture-slack"),
    do: {:ok, %{channel: "C-REVIEW", conversation: %{"id" => "C-REVIEW", "name" => "review"}}}
end
