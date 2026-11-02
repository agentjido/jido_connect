defmodule Jido.Connect.Tempo.Actions.Worklogs do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Tempo.ScopeResolver

  actions do
    action :list_own_worklogs do
      id("tempo.worklogs.list_own")
      resource(:worklog)
      verb(:list)
      data_classification(:personal_data)
      label("List own worklogs")

      description(
        "List every Tempo worklog of the connected account with a booking day " <>
          "from from to to, both inclusive. Fails as a whole instead of returning part of the range."
      )

      handler(Jido.Connect.Tempo.Handlers.Actions.ListOwnWorklogs)
      effect(:read)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        scopes(["tempo.worklogs.read"], resolver: @scope_resolver)
      end

      input do
        field(:from, :string,
          required?: true,
          example: "2026-10-01",
          description: "First booking day, an ISO date (YYYY-MM-DD)."
        )

        field(:to, :string,
          required?: true,
          example: "2026-10-31",
          description: "Last booking day, an ISO date (YYYY-MM-DD), not before from."
        )
      end

      output do
        field(:account_id, :string,
          description: "Atlassian account ID of the connection, the author of every worklog."
        )

        field(:from, :string, description: "First booking day of the range, as supplied.")
        field(:to, :string, description: "Last booking day of the range, as supplied.")

        field(:worklogs, {:array, :map},
          description:
            "Worklogs in Tempo's order, each with tempo_worklog_id, author_account_id, " <>
              "start_date (the booking day), time_spent_seconds, issue_id (the numeric Jira " <>
              "issue ID, readable with jira.issue.get), description (null when Tempo sent " <>
              "none) and work_attributes, and when Tempo sent them start_time, " <>
              "start_date_time_utc, billable_seconds, created_at, updated_at and self."
        )

        field(:complete, :boolean,
          description:
            "True when every page of the range was read. It marks exhausted pagination, " <>
              "not a snapshot or a write receipt."
        )
      end
    end
  end
end
