defmodule Jido.Connect.Examples.StartHere.GitHubWebhook do
  @moduledoc "Reads the current PR when the host delivers a verified GitHub Signal."

  alias Jido.Connect.{GitHub, Plugin}
  alias Jido.Connect.GitHub.Actions.GetPullRequest
  alias Jido.Joi

  @trigger "github.webhook.pull_request"

  use Jido.Agent, name: "connect_github_webhook", plugins: [Plugin]

  state do
    schema(Joi.object(%{pull_request: Joi.map() |> Joi.default(%{})}))
  end

  connect do
    binding :source, GitHub do
      triggers([@trigger])
      signals([@trigger])
      actions([GetPullRequest])
    end
  end

  routes do
    route(@trigger, __MODULE__.Read, as: :read_update)
  end

  defmodule Read do
    @moduledoc false

    use Jido.Flow,
      name: "connect_read_pr_on_webhook",
      schema:
        Joi.object(%{
          repo: Joi.string(),
          pull_number: Joi.integer() |> Joi.min(1),
          action: Joi.string(),
          delivery_id: Joi.string()
        })

    flow do
      step("read_pr",
        action: GetPullRequest,
        params: %{repo: input(:repo), pull_number: input(:pull_number)}
      )

      output(%{
        pull_request: %{
          number: result("read_pr", [:pull_request, :number]),
          title: result("read_pr", [:pull_request, :title])
        }
      })
    end
  end
end
