defmodule Jido.Connect.Google.Meet.Handlers.Triggers.TranscriptCheckpoint do
  @moduledoc false

  # The checkpoint of `google.meet.transcript.available`: a watermark on
  # conference end times, the records at or after the watermark that need no
  # further check, and the records still waiting for a generated transcript.
  # A record needs no further check once it is settled or has left the
  # pending set by age or count; such records are kept under `settled` with
  # their end time. The watermark never passes the end time of a pending
  # record, so a record that ends after a pending one is still found if it is
  # listed before that record leaves the pending set.
  # Hosts persist the checkpoint as the JSON string `encode/1` returns. The
  # package README documents the shape, the bounds, and when a record listed
  # late is missed.

  alias Jido.Connect.Error
  alias Jido.Connect.Google.Checkpoint

  @version 1

  # A pending record leaves the checkpoint once it is settled, older than
  # `@max_pending_age_seconds`, or beyond the `@max_pending` most recent ones.
  @max_pending 50
  @max_pending_age_seconds 24 * 60 * 60

  defstruct [:watermark, settled: [], pending: []]

  @doc "Starts a checkpoint whose watermark is `now`."
  def new(%DateTime{} = now), do: %__MODULE__{watermark: now}

  @doc """
  Builds the conference record filter for end times at or after `watermark`.

  Every conference record started after 1970, so the `start_time` clause
  leaves the matches unchanged. It keeps paging stable: live, with the
  `end_time` clause alone, a later page often repeated the first record under
  a fresh page token.
  """
  def window_filter(%DateTime{} = watermark) do
    ~s(end_time>="#{DateTime.to_iso8601(watermark)}" AND start_time>="1970-01-01T00:00:00Z")
  end

  @doc "True when the record is pending or needs no further check."
  def known?(%__MODULE__{} = checkpoint, name) do
    Enum.any?(checkpoint.settled, &(&1.name == name)) or
      Enum.any?(checkpoint.pending, &(&1.name == name))
  end

  @doc """
  Moves the pending records past the age bound under `settled` before a
  poll, so it lists neither their transcripts nor them as new records.
  """
  def expire(%__MODULE__{} = checkpoint, %DateTime{} = now) do
    {pending, aged} = Enum.split_with(checkpoint.pending, &recent?(&1, now))
    %{checkpoint | pending: pending, settled: checkpoint.settled ++ Enum.map(aged, &done/1)}
  end

  @doc """
  Advances the checkpoint over the records checked in one poll.

  Each checked record carries `name`, `end_time`, `emitted` and `settled?`.
  Open records stay pending within the count and age bounds. Settled records
  and records that leave the pending set are done. Without pending records
  the watermark moves to the latest end time of a done record; with them, to
  the latest end time of a done record before the oldest pending one. It
  never moves back. Done records at or after the watermark stay under
  `settled`, so the inclusive window filter lists them again without effect.
  """
  def advance(%__MODULE__{} = checkpoint, checked, %DateTime{} = now) do
    {open, settled} = Enum.split_with(checked, &(not &1.settled?))
    {pending, dropped} = bound_pending(open, now)
    done = checkpoint.settled ++ Enum.map(settled ++ dropped, &done/1)
    watermark = watermark(checkpoint.watermark, done, pending)

    %__MODULE__{
      watermark: watermark,
      settled:
        done
        |> Enum.filter(&(DateTime.compare(&1.end_time, watermark) != :lt))
        |> Enum.sort_by(&{DateTime.to_unix(&1.end_time, :microsecond), &1.name}),
      pending: Enum.map(pending, &Map.take(&1, [:name, :end_time, :emitted]))
    }
  end

  defp watermark(current, done, []), do: latest(current, done)

  defp watermark(current, done, pending) do
    oldest_pending = pending |> Enum.map(& &1.end_time) |> Enum.min(DateTime)
    latest(current, Enum.filter(done, &(DateTime.compare(&1.end_time, oldest_pending) == :lt)))
  end

  defp latest(current, records),
    do: Enum.max([current | Enum.map(records, & &1.end_time)], DateTime)

  defp bound_pending(open, now) do
    {recent, aged} = Enum.split_with(open, &recent?(&1, now))

    {pending, overflow} =
      recent
      |> Enum.sort_by(& &1.end_time, {:desc, DateTime})
      |> Enum.split(@max_pending)

    {pending, aged ++ overflow}
  end

  defp recent?(record, now) do
    cutoff = DateTime.add(now, -@max_pending_age_seconds, :second)
    DateTime.compare(record.end_time, cutoff) != :lt
  end

  defp done(record), do: Map.take(record, [:name, :end_time])

  @doc "Decodes a checkpoint string written by `encode/1`."
  def decode(checkpoint) when is_binary(checkpoint) do
    with {:ok,
          %{
            "version" => @version,
            "watermark" => watermark,
            "settled" => settled,
            "pending" => pending
          }} <- JSON.decode(checkpoint),
         {:ok, watermark} <- parse_time(watermark),
         {:ok, settled} <- decode_entries(settled, &decode_settled/1),
         {:ok, pending} <- decode_entries(pending, &decode_pending/1) do
      {:ok, %__MODULE__{watermark: watermark, settled: settled, pending: pending}}
    else
      _invalid -> invalid_checkpoint()
    end
  end

  def decode(_checkpoint), do: invalid_checkpoint()

  @doc "Encodes a checkpoint as the JSON string hosts persist."
  def encode(%__MODULE__{} = checkpoint) do
    JSON.encode!(%{
      "version" => @version,
      "watermark" => DateTime.to_iso8601(checkpoint.watermark),
      "settled" =>
        Enum.map(checkpoint.settled, fn record ->
          %{"name" => record.name, "end_time" => DateTime.to_iso8601(record.end_time)}
        end),
      "pending" =>
        Enum.map(checkpoint.pending, fn record ->
          %{
            "name" => record.name,
            "end_time" => DateTime.to_iso8601(record.end_time),
            "emitted" => record.emitted
          }
        end)
    })
  end

  @doc "Parses an RFC 3339 timestamp from the Meet API or a checkpoint."
  def parse_time(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, time, _offset} -> {:ok, time}
      {:error, _reason} -> :error
    end
  end

  def parse_time(_value), do: :error

  defp decode_entries(entries, decode) when is_list(entries) do
    Enum.reduce_while(entries, {:ok, []}, fn entry, {:ok, acc} ->
      case decode.(entry) do
        {:ok, entry} -> {:cont, {:ok, [entry | acc]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, entries} -> {:ok, Enum.reverse(entries)}
      :error -> :error
    end
  end

  defp decode_entries(_entries, _decode), do: :error

  defp decode_settled(%{"name" => name, "end_time" => end_time}) when is_binary(name) do
    with {:ok, end_time} <- parse_time(end_time), do: {:ok, %{name: name, end_time: end_time}}
  end

  defp decode_settled(_entry), do: :error

  defp decode_pending(%{"name" => name, "end_time" => end_time, "emitted" => emitted})
       when is_binary(name) do
    with {:ok, end_time} <- parse_time(end_time),
         true <- names?(emitted) do
      {:ok, %{name: name, end_time: end_time, emitted: emitted}}
    else
      _invalid -> :error
    end
  end

  defp decode_pending(_entry), do: :error

  defp names?(names), do: is_list(names) and Enum.all?(names, &is_binary/1)

  defp invalid_checkpoint do
    {:error,
     Error.validation("Google Meet transcript checkpoint is invalid",
       reason: :invalid_checkpoint,
       details: %{field: :checkpoint, checkpoint_reset: Checkpoint.reset_guidance()}
     )}
  end
end
