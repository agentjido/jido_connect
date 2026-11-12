defmodule Jido.Connect.Tempo.Actions.Accounts do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Tempo.ScopeResolver

  actions do
    action :list_accounts_for_project do
      id("tempo.account.list_for_project")
      resource(:account)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List accounts for project")

      description(
        "List the Tempo accounts that a Jira project offers for booking: its linked and " <>
          "global accounts, each with key, status and link evidence. Fails as a whole " <>
          "instead of returning an account without its details."
      )

      handler(Jido.Connect.Tempo.Handlers.Actions.ListAccountsForProject)
      effect(:read)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        scopes(["tempo.accounts.read"], resolver: @scope_resolver)
      end

      input do
        field(:project_id, :integer,
          required?: true,
          minimum: 1,
          example: 10_001,
          description:
            "Jira project ID of the booking target as a positive integer, not the project " <>
              "key. Jira returns the ID as a string such as \"10001\"; the host converts it."
        )
      end

      output do
        field(:project_id, :integer, description: "Numeric Jira project ID, as supplied.")

        field(:accounts, {:array, :map},
          description:
            "Account candidates in Tempo's link order, each with id, key (the value of an " <>
              "ACCOUNT work attribute), name, status (OPEN, CLOSED, ARCHIVED or another raw " <>
              "value), global, self and links: one map per link of the project with id (0 " <>
              "for a global account), default, scope_type and scope_id."
        )
      end
    end
  end
end
