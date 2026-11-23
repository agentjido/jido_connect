Code.require_file("../support/load.exs", __DIR__)
Code.require_file("triage_with_slack.ex", __DIR__)

alias Jido.Connect.Examples.StartHere.{Host, TriageWithSlack}

mode = Host.live_mode!([:github, :slack])
repo = Host.repo(mode)
channel = if mode == :live, do: Host.required_env!("SLACK_CHANNEL_ID"), else: "C-REVIEW"

signal =
  TriageWithSlack.triage_signal!(%{
    repo: repo,
    pull_number: Host.pull_number(mode),
    channel: channel
  })

context = %{
  connect: %{source: Host.github(repo, mode), review_channel: Host.slack(channel, mode)}
}

Host.with_agent(TriageWithSlack, fn server ->
  Host.call(server, signal, context)
end)
|> Host.print!()
