defmodule Jido.Connect.Tempo.Client.Worklogs do
  @moduledoc """
  Tempo worklog reads.

  `list_own/2` reads `GET /4/worklogs/user/{accountId}` for the request's
  `account_id`, which comes from the connection's `subject.account_id` and
  is sent percent-encoded as one path segment. It sends `from` and `to` and
  lets `Jido.Connect.Tempo.Client.Pagination` add `offset` and `limit`; it
  never sends `updatedFrom`, so the result is every worklog with a booking
  day in the range, not the ones changed since a point in time.

  The read succeeds only as a whole. It fails when a page fails or is
  malformed, when a worklog does not normalize with
  `Jido.Connect.Tempo.Worklog.normalize/1`, when a worklog's
  `author.accountId` is not the request's account ID, and when a booking day
  lies outside the range. These are `Jido.Connect.Error.ProviderError`s with
  `delivery: :response_received` and the reasons `:invalid_worklog`,
  `:foreign_worklog_author` and `:worklog_outside_range`; their details
  carry the Tempo ID and field names, never a description or another
  account's ID.
  """

  alias Jido.Connect.Error
  alias Jido.Connect.Tempo.Client.{Pagination, Request, Response}
  alias Jido.Connect.Tempo.Input.DateRange
  alias Jido.Connect.Tempo.Worklog

  @bounds [:limit, :max_pages, :max_results]

  @doc """
  Reads every worklog of the request's account with a booking day from
  `:from` to `:to`, both inclusive.

  `:from` and `:to` are ISO dates in the form `YYYY-MM-DD`, with `:from` not
  after `:to`; anything else is a `Jido.Connect.Error.ValidationError` with
  reason `:invalid_date_range` before any request. The optional `:limit`,
  `:max_pages` and `:max_results` bound the read as
  `Jido.Connect.Tempo.Client.Pagination.collect/3` describes.

  Returns the worklogs in Tempo's order.
  """
  @spec list_own(Request.t(), keyword()) ::
          {:ok, [Worklog.t()]} | {:error, Error.ProviderError.t() | Error.ValidationError.t()}
  def list_own(%Request{} = request, opts) when is_list(opts) do
    with {:ok, range} <- DateRange.parse(Keyword.get(opts, :from), Keyword.get(opts, :to)),
         {:ok, results} <-
           Pagination.collect(
             request,
             path(request),
             [params: [from: range.from, to: range.to]] ++ Keyword.take(opts, @bounds)
           ) do
      own(results, request.account_id, range)
    end
  end

  defp path(%Request{account_id: account_id}),
    do: "/4/worklogs/user/" <> URI.encode(account_id, &URI.char_unreserved?/1)

  defp own(results, account_id, range) do
    results
    |> Enum.reduce_while({:ok, []}, fn result, {:ok, worklogs} ->
      case check(result, account_id, range) do
        {:ok, worklog} -> {:cont, {:ok, [worklog | worklogs]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, worklogs} -> {:ok, Enum.reverse(worklogs)}
      error -> error
    end
  end

  defp check(result, account_id, range) do
    with {:ok, worklog} <- normalize(result) do
      day = Date.from_iso8601!(worklog.start_date)

      cond do
        worklog.author_account_id != account_id ->
          error(:foreign_worklog_author, "Tempo returned a worklog of another account", %{
            tempo_worklog_id: worklog.tempo_worklog_id
          })

        Date.compare(day, range.first) == :lt or Date.compare(day, range.last) == :gt ->
          error(:worklog_outside_range, "Tempo returned a worklog outside the range", %{
            tempo_worklog_id: worklog.tempo_worklog_id,
            start_date: worklog.start_date,
            from: range.from,
            to: range.to
          })

        true ->
          {:ok, worklog}
      end
    end
  end

  defp normalize(result) do
    case Worklog.normalize(result) do
      {:ok, worklog} ->
        {:ok, worklog}

      {:error, field} ->
        error(:invalid_worklog, "Tempo worklog was invalid", %{field: field})
    end
  end

  defp error(reason, message, details),
    do: Response.invalid_response(message, nil, reason: reason, details: details)
end
