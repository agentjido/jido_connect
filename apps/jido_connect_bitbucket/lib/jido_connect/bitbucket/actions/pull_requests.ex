defmodule Jido.Connect.Bitbucket.Actions.PullRequests do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  alias Jido.Connect.Bitbucket.PullRequestContract, as: Contract

  @slug_pattern Contract.slug_pattern()
  @states Contract.states()
  @default_state Contract.default_state()
  @default_limit Contract.default_limit()
  @minimum_limit Contract.minimum_limit()
  @maximum_limit Contract.maximum_limit()
  @default_page Contract.default_page()
  @maximum_page Contract.maximum_page()

  actions do
    action :list_pull_requests do
      id("bitbucket.pull_request.list")
      resource(:pull_request)
      verb(:list)
      data_classification(:workspace_content)
      label("List pull requests")
      description("List pull requests in one Bitbucket Cloud repository.")
      handler(Jido.Connect.Bitbucket.Handlers.Actions.ListPullRequests)
      effect(:read)

      access do
        auth([:api_token], default: :api_token)
        scopes(["read:pullrequest:bitbucket"])
      end

      input do
        field(:workspace, :string,
          required?: true,
          min_length: 1,
          max_length: 255,
          metadata: %{pattern: @slug_pattern},
          example: "acme"
        )

        field(:repository, :string,
          required?: true,
          min_length: 1,
          max_length: 255,
          metadata: %{pattern: @slug_pattern},
          example: "widgets"
        )

        field(:state, :string,
          enum: @states,
          default: @default_state
        )

        field(:limit, :integer,
          default: @default_limit,
          minimum: @minimum_limit,
          maximum: @maximum_limit
        )

        field(:page, :integer,
          default: @default_page,
          minimum: @default_page,
          maximum: @maximum_page
        )
      end

      output do
        field(:kind, :string)
        field(:account, :string)
        field(:workspace, :string)
        field(:repository, :string)
        field(:state, :string)
        field(:count, :integer)
        field(:page, :integer)
        field(:page_length, :integer)
        field(:total, :integer)
        field(:next_page, :string)
        field(:items, {:array, :map})
      end
    end
  end
end
