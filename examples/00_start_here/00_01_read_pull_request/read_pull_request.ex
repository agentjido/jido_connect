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
    route("examples.connect.pr.read", __MODULE__.Read, as: :read_pr)
  end

  defmodule Read do
    @moduledoc false

    use Jido.Flow,
      name: "connect_read_pr",
      schema: Joi.object(%{repo: Joi.string(), pull_number: Joi.integer() |> Joi.min(1)})

    flow do
      step("read_pr", action: GetPullRequest, params: input())

      step "summary", pr <- result("read_pr", :pull_request) do
        {:ok, Map.take(pr, [:number, :title, :state])}
      end

      output(%{pull_request: result("summary")})
    end
  end
end
