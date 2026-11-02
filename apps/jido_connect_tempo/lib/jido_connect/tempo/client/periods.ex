defmodule Jido.Connect.Tempo.Client.Periods do
  @moduledoc """
  Tempo period reads.

  `list/2` reads `GET /4/periods` with `from` and `to`. Tempo answers with
  every full period that intersects the range, also for a range that starts
  or ends inside a period, as `{"periods": [{"from": ..., "to": ...}]}`. The
  answer is not paginated and carries no status: a period has only its first
  and last day.

  A period whose `from` or `to` is not an ISO date, or whose `from` is after
  its `to`, and an answer without a `periods` list fail the read as a
  `Jido.Connect.Error.ProviderError` with reason `:invalid_periods` and
  `delivery: :response_received`.
  """

  alias Jido.Connect.Error
  alias Jido.Connect.Tempo.Client.{Request, Response, Transport}
  alias Jido.Connect.Tempo.Input.DateRange

  @type period :: %{from: String.t(), to: String.t()}

  @doc """
  Reads the periods that intersect the range from `:from` to `:to`, both
  inclusive.

  `:from` and `:to` are ISO dates in the form `YYYY-MM-DD`, with `:from` not
  after `:to`; anything else is a `Jido.Connect.Error.ValidationError` with
  reason `:invalid_date_range` before any request.

  Returns the periods in Tempo's order as `%{from: from, to: to}` maps with
  the full period boundaries.
  """
  @spec list(Request.t(), keyword()) ::
          {:ok, [period()]} | {:error, Error.ProviderError.t() | Error.ValidationError.t()}
  def list(%Request{} = request, opts) when is_list(opts) do
    with {:ok, range} <- DateRange.parse(Keyword.get(opts, :from), Keyword.get(opts, :to)),
         {:ok, body} <-
           Transport.get(request, "/4/periods", params: [from: range.from, to: range.to]) do
      periods(body)
    end
  end

  defp periods(%{"periods" => periods}) when is_list(periods) do
    periods
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {period, index}, {:ok, acc} ->
      case period(period) do
        {:ok, period} -> {:cont, {:ok, [period | acc]}}
        :error -> {:halt, invalid(%{index: index})}
      end
    end)
    |> case do
      {:ok, periods} -> {:ok, Enum.reverse(periods)}
      error -> error
    end
  end

  defp periods(_body), do: invalid(%{field: "periods"})

  # The date rule of a requested range applies to each period as well.
  defp period(%{"from" => from, "to" => to}) do
    case DateRange.parse(from, to) do
      {:ok, _range} -> {:ok, %{from: from, to: to}}
      {:error, _error} -> :error
    end
  end

  defp period(_period), do: :error

  defp invalid(details) do
    Response.invalid_response("Tempo periods were invalid", nil,
      reason: :invalid_periods,
      details: details
    )
  end
end
