defmodule Jido.Connect.Examples.StartHere.ReadPullRequest do
  @moduledoc "Reads one PR through a generated Connect Action on a live Agent."

  alias Jido.Connect.{GitHub, Plugin}
  alias Jido.Connect.GitHub.Actions.GetPullRequest
  alias Jido.Joi

  use Jido.Agent, name: "connect_read_pull_request", plugins: [Plugin]

  state do
    schema(Joi.object(%{pull_request: Joi.map() |> Joi.default(%{})}))
  end

  connect do
    binding :source, GitHub do
      actions([GetPullRequest])
    end
  end

  routes do
    signal_source("/examples/connect/read-pr")

    route "examples.connect.pr.read", as: :read_pr do
      action input,
        schema: Joi.object(%{repo: Joi.string(), pull_number: Joi.integer() |> Joi.min(1)}),
        context: context do
        with {:ok, access} <- Plugin.action_context(context, :source, GetPullRequest),
             {:ok, %{pull_request: pr}} <-
               Jido.Exec.run(GetPullRequest, input, access, deadline_ms: 15_000) do
          {:ok, %{pull_request: Map.take(pr, [:number, :title, :state])}}
        end
      end
    end
  end
end
