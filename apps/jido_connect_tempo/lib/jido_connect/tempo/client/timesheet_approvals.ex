defmodule Jido.Connect.Tempo.Client.TimesheetApprovals do
  @moduledoc """
  Tempo timesheet approval reads.

  `get/3` reads `GET /4/timesheet-approvals/user/{accountId}` for the
  request's `account_id`, which comes from the connection's
  `subject.account_id` and is sent percent-encoded as one path segment. It
  sends `from` and `to` as given. Tempo accepts only the exact first and
  last day of one period; a range that does not match one period, such as
  one across two periods, gets a 400 whose message names the period of
  `from`. Read `Jido.Connect.Tempo.Client.Periods.list/2` first for the
  boundaries.

  The answer is normalized with `Jido.Connect.Tempo.TimesheetApproval.normalize/1`
  and must name the request's account and exactly the requested period.
  Otherwise the read fails with a `Jido.Connect.Error.ProviderError` with
  `delivery: :response_received` and reason `:invalid_timesheet_approval`
  (details: the Tempo field path), `:foreign_approval_user` (details: the
  requested `from` and `to`, never the other account) or
  `:approval_period_mismatch` (details: the requested and the returned
  boundaries).

  The read never follows the `actions` links of the answer, such as
  `submit` or `recall`, and sends no other request.
  """

  alias Jido.Connect.Error
  alias Jido.Connect.Tempo.Client.{Request, Response, Transport}
  alias Jido.Connect.Tempo.Input.DateRange
  alias Jido.Connect.Tempo.TimesheetApproval

  @doc """
  Reads the request account's approval of the period from `from` to `to`.

  `from` and `to` are ISO dates in the form `YYYY-MM-DD`, with `from` not
  after `to`; anything else is a `Jido.Connect.Error.ValidationError` with
  reason `:invalid_date_range` before any request.
  """
  @spec get(Request.t(), String.t(), String.t()) ::
          {:ok, TimesheetApproval.t()}
          | {:error, Error.ProviderError.t() | Error.ValidationError.t()}
  def get(%Request{} = request, from, to) do
    with {:ok, range} <- DateRange.parse(from, to),
         {:ok, body} <-
           Transport.get(request, Request.account_path(request, "/4/timesheet-approvals/user/"),
             params: [from: range.from, to: range.to]
           ),
         {:ok, approval} <- normalize(body) do
      check(approval, request.account_id, range)
    end
  end

  defp normalize(body) do
    case TimesheetApproval.normalize(body) do
      {:ok, approval} ->
        {:ok, approval}

      {:error, field} ->
        error(:invalid_timesheet_approval, "Tempo timesheet approval was invalid", %{
          field: field
        })
    end
  end

  # The evidence counts only for the requested user and period. The details
  # name the requested range, never the other account.
  defp check(%TimesheetApproval{} = approval, account_id, range) do
    cond do
      approval.user_account_id != account_id ->
        error(:foreign_approval_user, "Tempo returned the approval of another user", %{
          from: range.from,
          to: range.to
        })

      {approval.period_from, approval.period_to} != {range.from, range.to} ->
        error(:approval_period_mismatch, "Tempo returned the approval of another period", %{
          from: range.from,
          to: range.to,
          period_from: approval.period_from,
          period_to: approval.period_to
        })

      true ->
        {:ok, approval}
    end
  end

  defp error(reason, message, details),
    do: Response.invalid_response(message, nil, reason: reason, details: details)
end
