defmodule Jido.Connect.Tempo.Handlers.Actions.GetPeriodBookability do
  @moduledoc false

  # The account is the connection's subject.account_id, bound in the
  # request; the input carries only the range. The range is checked before
  # the provider client is resolved, so an injected client never receives an
  # invalid one. checked_at is taken before the first request, so every
  # reported evidence was read at or after it. The approval reads keep the
  # default bound of PeriodBookability.build/4; the input cannot change it.

  alias Jido.Connect.Tempo.{Client, PeriodBookability}
  alias Jido.Connect.Tempo.Input.DateRange

  def run(%{from: from, to: to}, runtime) do
    with {:ok, _range} <- DateRange.parse(from, to),
         {:ok, request} <- Client.request_context(runtime),
         client = Client.resolve(runtime),
         checked_at = checked_at(),
         {:ok, periods} <- client.list_periods(request, from: from, to: to),
         {:ok, bookability} <-
           PeriodBookability.build(
             %{account_id: request.account_id, from: from, to: to, checked_at: checked_at},
             periods,
             &client.get_timesheet_approval(request, &1.from, &1.to)
           ) do
      {:ok, PeriodBookability.to_map(bookability)}
    end
  end

  defp checked_at do
    DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
  end
end
