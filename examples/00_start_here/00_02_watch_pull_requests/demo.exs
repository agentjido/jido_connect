Code.require_file("../support/load.exs", __DIR__)
Code.require_file("watch_pull_requests.ex", __DIR__)

alias Jido.Connect.Examples.StartHere.{Host, WatchPullRequests}

mode = Host.live_mode!([:github])
repo = Host.repo(mode)
access = Host.github(repo, mode)

Host.with_agent(WatchPullRequests, fn server ->
  {:ok, watch, _schedule} = WatchPullRequests.watch(repo, access)

  with {:ok, watch, directives} <- WatchPullRequests.tick(watch, access) do
    # The provider returns updates in time order. Show the last event from this poll.
    signals = for {:emit, signal} <- directives, do: signal

    case List.last(signals) do
      nil ->
        {:ok, %{updates: 0, checkpoint: watch.checkpoint}}

      signal ->
        with {:ok, state} <- Host.call(server, signal, %{connect: %{source: access}}) do
          {:ok, Map.merge(state, %{updates: length(signals), checkpoint: watch.checkpoint})}
        end
    end
  end
end)
|> Host.print!()
