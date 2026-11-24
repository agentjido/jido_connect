defmodule Jido.Connect.Slack.LiveSlackCapturesTest do
  use ExUnit.Case, async: true

  # The Slack live tests read the demo host's captures through
  # `LiveSlack.captures/2`. The demo host keeps 20 slots per directory, so a
  # longer run moves full batches into subdirectories.

  alias Jido.Connect.Slack.TestSupport.LiveSlack

  setup do
    dir =
      Path.join(System.tmp_dir!(), "live-slack-captures-#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(dir, "batch-1"))
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir}
  end

  test "reads more than 20 captures across moved batches in capture order", %{dir: dir} do
    for slot <- 1..20 do
      route = if rem(slot, 5) == 0, do: "interactivity", else: "events"
      write!(Path.join([dir, "batch-1", "slack-#{slot}.json"]), route, 1_000 + slot, "b1-#{slot}")
    end

    for slot <- 1..5,
        do: write!(Path.join(dir, "slack-#{slot}.json"), "events", 2_000 + slot, "b2-#{slot}")

    # Two captures of one second keep their slot order, also past slot 9.
    write!(Path.join(dir, "slack-10.json"), "events", 2_005, "b2-10")

    events = LiveSlack.captures(dir, "events")

    assert length(events) == 22

    assert Enum.map(events, & &1["body"]) ==
             Enum.sort_by(Enum.map(events, & &1["body"]), &order/1)

    assert List.last(events)["body"] == "b2-10"
    assert length(LiveSlack.captures(dir, "interactivity")) == 4
  end

  test "keeps a moved batch before the directory the demo host writes to within one second",
       %{dir: dir} do
    write!(Path.join(dir, "slack-1.json"), "events", 4_000, "newer")
    write!(Path.join([dir, "batch-1", "slack-20.json"]), "events", 4_000, "older")

    assert Enum.map(LiveSlack.captures(dir, "events"), & &1["body"]) == ["older", "newer"]
  end

  test "sorts a renamed capture after the numbered ones of its directory", %{dir: dir} do
    write!(Path.join(dir, "slack-2.json"), "events", 3_000, "numbered")
    write!(Path.join(dir, "slack-kept.json"), "events", 3_000, "renamed")

    assert Enum.map(LiveSlack.captures(dir, "events"), & &1["body"]) == ["numbered", "renamed"]
  end

  defp write!(path, route, captured_at, body) do
    capture = %{
      "provider" => "slack",
      "method" => "POST",
      "path" => "/integrations/slack/#{route}",
      "captured_at" => captured_at,
      "headers" => %{},
      "body" => body
    }

    File.write!(path, Jason.encode!(capture))
  end

  # Batch 1 before batch 2, then by slot.
  defp order(body) do
    [batch, slot] = String.split(body, "-")
    {batch, String.to_integer(slot)}
  end
end
