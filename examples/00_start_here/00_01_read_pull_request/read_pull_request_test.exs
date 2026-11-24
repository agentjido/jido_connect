Code.require_file("read_pull_request.ex", __DIR__)

defmodule Jido.Connect.Examples.StartHere.ReadPullRequestTest do
  use ExUnit.Case
  @moduletag :integration

  alias Jido.Connect.Examples.StartHere.{Host, ReadPullRequest}

  test "a routed PR read uses the named GitHub binding, and the host denies other repositories" do
    repo = "example/widgets"
    context = %{connect: %{source: Host.github(repo, :fixture)}}

    server =
      Host.with_agent(ReadPullRequest, fn server ->
        signal = ReadPullRequest.read_pr_signal!(%{repo: repo, pull_number: 42})

        assert {:ok, %{pull_request: %{number: 42, title: "Update the widgets"}}} =
                 Host.call(server, signal, context)

        state = Jido.AgentServer.snapshot(server).agent.state
        denied = ReadPullRequest.read_pr_signal!(%{repo: "example/other", pull_number: 42})
        assert {:error, _reason} = Host.call(server, denied, context)
        assert Jido.AgentServer.snapshot(server).agent.state == state
        server
      end)

    refute Process.alive?(server)
  end
end
