defmodule Jido.Connect.Tempo.Actions.Periods do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Tempo.ScopeResolver

  actions do
    action :get_period_bookability do
      id("tempo.period.bookability.get")
      resource(:period)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get period bookability")

      description(
        "Return the connected account's approval evidence for every Tempo period that " <>
          "intersects from to to, both inclusive, with closure evidence unknown and a state " <>
          "derived from the evidence. The result is neither a reservation nor a write guarantee."
      )

      handler(Jido.Connect.Tempo.Handlers.Actions.GetPeriodBookability)
      effect(:read)

      access do
        auth([:api_token, :oauth2_user], default: :api_token)
        scopes(["tempo.periods.read", "tempo.approvals.read"], resolver: @scope_resolver)
      end

      input do
        field(:from, :string,
          required?: true,
          example: "2026-10-01",
          description: "First day of the range, an ISO date (YYYY-MM-DD)."
        )

        field(:to, :string,
          required?: true,
          example: "2026-10-31",
          description: "Last day of the range, an ISO date (YYYY-MM-DD), not before from."
        )
      end

      output do
        field(:account_id, :string,
          description: "Atlassian account ID of the connection, the user of every approval."
        )

        field(:from, :string, description: "First day of the range, as supplied.")
        field(:to, :string, description: "Last day of the range, as supplied.")

        field(:checked_at, :string,
          description: "UTC time before the first Tempo request, ISO 8601 to the second."
        )

        field(:complete, :boolean,
          description:
            "True when the segments cover every day of the range and each has an approval " <>
              "status. False marks missing evidence, not a failure of the whole read."
        )

        field(:state, :any,
          enum: [:blocked, :unknown],
          description:
            "Derived, not read from Tempo: blocked when any segment is blocked, else unknown. " <>
              "Never bookable, since closure evidence is unknown."
        )

        field(:segments, {:array, :map},
          description:
            "One segment per intersecting period, ordered by date, with from and to (the part " <>
              "of the range in the period), period_from and period_to (the full period), " <>
              "approval_status (OPEN, IN_REVIEW, APPROVED, another raw key, or null when no " <>
              "status was read), approval_updated_at (null when Tempo sent none), " <>
              "approval_error (null when the approval read returned an approval, else the " <>
              "reason, status and retry_after of the failed read), closure_evidence (always " <>
              "unknown) and state (blocked for IN_REVIEW or APPROVED, else unknown)."
        )
      end
    end
  end
end
