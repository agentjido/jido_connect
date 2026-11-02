defmodule Jido.Connect.Tempo.PeriodBookability do
  @moduledoc """
  Approval evidence of the Tempo periods that intersect a date range, and
  the state derived from it.

  `tempo.period.bookability.get` returns this result as plain maps.

  ## Evidence

  | Field | Meaning |
  | --- | --- |
  | `account_id` | the connection's `subject.account_id`, the user of every approval |
  | `from`, `to` | the requested range as supplied, both inclusive |
  | `checked_at` | UTC time before the first Tempo request, ISO 8601 to the second |
  | `complete` | `true` when the segments cover every day of the range once and each has an approval status |
  | `segments` | one `Jido.Connect.Tempo.PeriodBookability.Segment` per intersecting period, ordered by date |

  Each segment holds the part of the range in its period, the full period,
  Tempo's `approval_status` and `approval_updated_at` as sent,
  `approval_error` and `closure_evidence: :unknown`. No public Tempo Cloud
  API reads manual period closures, Scheduler freezes or grace periods, so
  closure evidence is always unknown.

  A segment's `approval_status` is `nil` when no status was read: Tempo sent
  none, its approval read failed, or the answer named another user or
  another period. A missing status is never read as `OPEN`. Such a segment,
  and a range that Tempo's periods leave uncovered or cover twice, set
  `complete: false`; the other segments keep their evidence.

  `approval_error` tells these cases apart. It is `nil` when the approval
  read returned an approval, also one without a status. Otherwise it holds
  the `reason`, `status` and `retry_after` of the failed read's
  `Jido.Connect.Error.ProviderError`, such as `%{reason: :forbidden, status:
  403, retry_after: nil}`, `%{reason: :rate_limited, status: 429,
  retry_after: 30}` or `%{reason: :foreign_approval_user, status: nil,
  retry_after: nil}`. Any other error, such as one of an injected client or
  a provider error without an atom reason, is `%{reason:
  :approval_read_failed, status: nil, retry_after: nil}`. The error's
  message, details and Tempo's body are never kept.

  ## Derived State

  `state` is derived from the evidence, not read from Tempo:

  - a segment is `:blocked` when its `approval_status` is `IN_REVIEW` or
    `APPROVED`, else `:unknown`, also for `OPEN`, an unfamiliar key and a
    missing status;
  - the result is `:blocked` when any segment is, else `:unknown`.

  `:bookable` would need closure evidence and is never derived. `complete:
  false` never weakens a blocked segment. The result is neither a
  reservation nor a write guarantee: Tempo can change an approval or close
  a period after `checked_at`, and a write into a closed period is rejected
  only when it is made.
  """

  alias Jido.Connect.Error
  alias Jido.Connect.Tempo.Input.DateRange
  alias Jido.Connect.Tempo.PeriodBookability.Segment
  alias Jido.Connect.Tempo.TimesheetApproval

  @schema Zoi.struct(
            __MODULE__,
            %{
              account_id: Zoi.string() |> Zoi.min(1),
              from: Zoi.ISO.date(),
              to: Zoi.ISO.date(),
              checked_at: Zoi.ISO.datetime(),
              complete: Zoi.boolean(),
              state: Zoi.enum([:blocked, :unknown]),
              segments: Zoi.list(Segment.schema())
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @type period :: %{from: String.t(), to: String.t()}
  @type approval_result :: {:ok, TimesheetApproval.t()} | {:error, term()}

  @blocking ["IN_REVIEW", "APPROVED"]
  @max_periods 20

  @doc """
  Builds the result for the range of `attrs` from Tempo's `periods`.

  `attrs` holds `account_id`, `from` and `to` (valid ISO dates, `from` not
  after `to`) and `checked_at`. `periods` are `%{from: from, to: to}` maps
  as `Jido.Connect.Tempo.Client.list_periods/2` returns them; a period
  outside the range is dropped. `read_approval` is called once for each
  remaining period, in date order, with that period and returns its
  approval as `Jido.Connect.Tempo.Client.get_timesheet_approval/3` does; an
  error leaves the segment without evidence and sets its `approval_error`.

  `:max_periods` (#{@max_periods}) bounds the approval reads: more
  intersecting periods fail with a `Jido.Connect.Error.ProviderError` with
  reason `:period_limit_exceeded` and `details.max_periods` before the
  first read; exactly this many succeed. A bound that is not a positive
  integer is a `Jido.Connect.Error.ValidationError` with reason
  `:invalid_bookability_option`, also before any read.
  """
  @spec build(map(), [period()], (period() -> approval_result()), keyword()) ::
          {:ok, t()} | {:error, Error.ProviderError.t() | Error.ValidationError.t()}
  def build(%{from: from, to: to} = attrs, periods, read_approval, opts \\ []) do
    {:ok, range} = DateRange.parse(from, to)

    intersections =
      periods
      |> Enum.flat_map(&intersection(&1, range))
      |> Enum.sort_by(&elem(&1, 0), Date)

    with {:ok, max_periods} <- max_periods(opts),
         :ok <- within(intersections, max_periods) do
      segments =
        Enum.map(intersections, fn {first, last, period} ->
          segment(first, last, period, read_approval.(period))
        end)

      {:ok,
       Zoi.parse!(@schema, %{
         account_id: attrs.account_id,
         from: from,
         to: to,
         checked_at: attrs.checked_at,
         complete:
           covered?(intersections, range) and Enum.all?(segments, &is_binary(&1.approval_status)),
         state: if(Enum.any?(segments, &(&1.state == :blocked)), do: :blocked, else: :unknown),
         segments: segments
       })}
    end
  end

  @doc "Returns the result as plain maps for action output."
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = bookability) do
    bookability
    |> Map.from_struct()
    |> Map.update!(:segments, fn segments -> Enum.map(segments, &Map.from_struct/1) end)
  end

  defp max_periods(opts) do
    case Keyword.get(opts, :max_periods, @max_periods) do
      max when is_integer(max) and max > 0 ->
        {:ok, max}

      _other ->
        {:error,
         Error.validation("Invalid Tempo period bookability option",
           reason: :invalid_bookability_option,
           subject: :max_periods,
           details: %{option: :max_periods, message: "must be a positive integer"}
         )}
    end
  end

  # One approval read per intersecting period, at most max_periods.
  defp within(intersections, max_periods) when length(intersections) <= max_periods, do: :ok

  defp within(_intersections, max_periods) do
    {:error,
     Error.provider("Tempo range exceeds the period limit",
       provider: :tempo,
       reason: :period_limit_exceeded,
       delivery: :response_received,
       details: %{max_periods: max_periods}
     )}
  end

  # The part of the range in the period as {first, last, period}, or none.
  defp intersection(%{from: from, to: to} = period, range) do
    first = Date.from_iso8601!(from)
    last = Date.from_iso8601!(to)

    if Date.compare(first, range.last) == :gt or Date.compare(last, range.first) == :lt do
      []
    else
      [{Enum.max([first, range.first], Date), Enum.min([last, range.last], Date), period}]
    end
  end

  defp segment(first, last, period, approval) do
    {status, updated_at, approval_error} = evidence(approval)

    Segment.new!(%{
      from: Date.to_iso8601(first),
      to: Date.to_iso8601(last),
      period_from: period.from,
      period_to: period.to,
      approval_status: status,
      approval_updated_at: updated_at,
      approval_error: approval_error,
      closure_evidence: :unknown,
      state: if(status in @blocking, do: :blocked, else: :unknown)
    })
  end

  # A failed or rejected read is no evidence, not a status. Of the error
  # only its reason, status and retry_after are kept: never its message,
  # its details or a Tempo body.
  defp evidence({:ok, %TimesheetApproval{status: status, updated_at: updated_at}}),
    do: {status, updated_at, nil}

  defp evidence({:error, error}), do: {nil, nil, approval_error(error)}

  defp approval_error(%Error.ProviderError{reason: reason, status: status, details: details})
       when is_atom(reason) and not is_nil(reason) do
    %{reason: reason, status: status, retry_after: retry_after(details)}
  end

  defp approval_error(_error),
    do: %{reason: :approval_read_failed, status: nil, retry_after: nil}

  defp retry_after(%{retry_after: seconds}) when is_integer(seconds), do: seconds
  defp retry_after(_details), do: nil

  # The intersections, in order, must cover every day of the range once.
  defp covered?([], _range), do: false

  defp covered?([{first, _last, _period} | _rest] = intersections, range) do
    {_first, last, _period} = List.last(intersections)

    first == range.first and last == range.last and
      intersections
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.all?(fn [{_first, previous, _}, {next, _last, _}] ->
        Date.add(previous, 1) == next
      end)
  end
end
