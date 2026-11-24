defmodule Jido.Connect.Examples.StartHere.CredentialLeases do
  @moduledoc "Reads a PR through either of two host-owned GitHub connections."

  alias Jido.Connect.{GitHub, Plugin}
  alias Jido.Connect.Examples.StartHere.LeaseHost
  alias Jido.Connect.GitHub.Actions.GetPullRequest
  alias Jido.Joi

  use Jido.Agent, name: "connect_credential_leases", plugins: [Plugin]

  state do
    schema(Joi.object(%{pull_request: Joi.map() |> Joi.default(%{})}))
  end

  connect do
    binding :widgets, GitHub do
      actions([GetPullRequest])
      signals(["examples.connect.leases.read_widgets"])
      credential_resolver(LeaseHost)
    end

    binding :gadgets, GitHub do
      actions([GetPullRequest])
      signals(["examples.connect.leases.read_gadgets"])
      credential_resolver(LeaseHost)
    end
  end

  routes do
    signal_source("/examples/connect/credential-leases")

    route("examples.connect.leases.read_widgets", __MODULE__.Read, as: :read_widgets)
    route("examples.connect.leases.read_gadgets", __MODULE__.Read, as: :read_gadgets)
  end

  defmodule Read do
    @moduledoc false

    use Jido.Flow,
      name: "connect_lease_read",
      schema: Joi.object(%{repo: Joi.string(), pull_number: Joi.integer() |> Joi.min(1)})

    flow do
      step("read_pr", action: GetPullRequest, params: input())

      output(%{
        pull_request: %{
          number: result("read_pr", [:pull_request, :number]),
          title: result("read_pr", [:pull_request, :title])
        }
      })
    end
  end
end
