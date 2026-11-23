defmodule Jido.Connect.Examples.StartHere.TriageWithSlack do
  @moduledoc "Reads a GitHub PR and the Slack channel where review would happen."

  alias Jido.Connect.{GitHub, Plugin, Slack}
  alias Jido.Connect.GitHub.Actions.GetPullRequest
  alias Jido.Connect.Slack.Actions.GetConversationInfo
  alias Jido.Joi

  use Jido.Agent, name: "connect_triage_with_slack", plugins: [Plugin]

  state do
    schema(Joi.object(%{review: Joi.map() |> Joi.default(%{})}))
  end

  connect do
    binding :source, GitHub do
      actions([GetPullRequest])
    end

    binding :review_channel, Slack do
      actions([GetConversationInfo])
    end
  end

  routes do
    signal_source("/examples/connect/triage")
    route("examples.connect.pr.triage", __MODULE__.Triage, as: :triage)
  end

  defmodule Triage do
    @moduledoc false

    use Jido.Flow,
      name: "connect_triage",
      schema:
        Joi.object(%{
          repo: Joi.string(),
          pull_number: Joi.integer() |> Joi.min(1),
          channel: Joi.string()
        })

    flow do
      step("read_pr",
        action: GetPullRequest,
        params: %{repo: input(:repo), pull_number: input(:pull_number)}
      )

      step("read_channel",
        action: GetConversationInfo,
        params: %{channel: input(:channel), conversation_type: "public_channel"},
        needs: ["read_pr"]
      )

      step "review",
           [
             pr <- result("read_pr", :pull_request),
             id <- result("read_channel", :channel),
             channel <- result("read_channel", :conversation)
           ] do
        {:ok,
         %{
           pull_number: pr.number,
           channel_id: id,
           channel_name: channel["name"],
           ready?: pr[:state] == "open" and pr[:draft] == false
         }}
      end

      output(%{review: result("review")})
    end
  end
end
