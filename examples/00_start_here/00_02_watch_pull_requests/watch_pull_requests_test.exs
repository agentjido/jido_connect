Code.require_file("watch_pull_requests.ex", __DIR__)

defmodule Jido.Connect.Examples.StartHere.WatchPullRequestsTest do
  use ExUnit.Case
  @moduletag :integration

  alias Jido.Connect.Examples.StartHere.{Host, WatchPullRequests}

  test "one tick routes a PR update and the next tick uses the checkpoint" do
    repo = "example/widgets"
    access = Host.github(repo, :fixture)
    assert {:ok, watch, [{:schedule, _interval}]} = WatchPullRequests.watch(repo, access)

    assert {:ok, watch, [{:emit, signal}, {:schedule, _interval}]} =
             WatchPullRequests.tick(watch, access)

    assert watch.checkpoint == "2026-01-01T00:00:00Z"

    server =
      Host.with_agent(WatchPullRequests, fn server ->
        assert {:ok, %{latest_update: %{repo: ^repo, pull_number: 42}}} =
                 Host.call(server, signal, %{connect: %{source: access}})

        server
      end)

    assert {:ok, watch, [{:schedule, _interval}]} = WatchPullRequests.tick(watch, access)
    assert watch.checkpoint == "2026-01-01T00:00:00Z"
    refute Process.alive?(server)
  end
end
