Code.require_file("triage_with_slack.ex", __DIR__)

defmodule Jido.Connect.Examples.StartHere.TriageWithSlackTest do
  use ExUnit.Case
  @moduletag :integration

  alias Jido.Connect.Examples.StartHere.{Host, TriageWithSlack}

  test "one turn reads through separate GitHub and Slack bindings" do
    repo = "example/widgets"
    channel = "C-REVIEW"
    github = Host.github(repo, :fixture)
    slack = Host.slack(channel, :fixture)
    signal = TriageWithSlack.triage_signal!(%{repo: repo, pull_number: 42, channel: channel})

    server =
      Host.with_agent(TriageWithSlack, fn server ->
        assert {:ok, %{review: %{pull_number: 42, channel_name: "review", ready?: true}}} =
                 Host.call(server, signal, %{connect: %{source: github, review_channel: slack}})

        state = Jido.AgentServer.snapshot(server).agent.state

        assert {:error, _reason} =
                 Host.call(server, signal, %{connect: %{source: github, review_channel: github}})

        assert Jido.AgentServer.snapshot(server).agent.state == state
        server
      end)

    refute Process.alive?(server)
  end
end
