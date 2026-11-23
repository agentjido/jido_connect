Code.require_file("../support/load.exs", __DIR__)
Code.require_file("read_pull_request.ex", __DIR__)

alias Jido.Connect.Examples.StartHere.{Host, ReadPullRequest}

mode = Host.live_mode!([:github])
repo = Host.repo(mode)
signal = ReadPullRequest.read_pr_signal!(%{repo: repo, pull_number: Host.pull_number(mode)})

Host.with_agent(ReadPullRequest, fn server ->
  Host.call(server, signal, %{connect: %{source: Host.github(repo, mode)}})
end)
|> Host.print!()
