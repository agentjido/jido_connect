defmodule Jido.Connect.Google.Meet.Handlers.Triggers.TranscriptPoller do
  @moduledoc false

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Google.Checkpoint
  alias Jido.Connect.Google.Meet.Handlers.Actions.ResourceHelpers
  alias Jido.Connect.Google.Meet.Handlers.Triggers.TranscriptCheckpoint

  # Google returns at most 100 conference records or transcripts per page.
  @page_size 100

  # Per poll: the conference records ending at or after the watermark.
  @conference_records %{
    resource: :conference_records,
    name: :conference_record_name,
    label: "conference record list",
    max_pages: 10,
    max_items: 100
  }

  # Per conference record: its transcripts.
  @transcripts %{
    resource: :transcripts,
    name: :transcript_name,
    label: "transcript list",
    max_pages: 5,
    max_items: 25
  }

  def poll(_config, %{checkpoint: checkpoint}) when checkpoint in [nil, ""] do
    now = DateTime.utc_now()
    {:ok, %{signals: [], checkpoint: TranscriptCheckpoint.encode(TranscriptCheckpoint.new(now))}}
  end

  def poll(_config, %{credentials: credentials, checkpoint: checkpoint}) do
    now = DateTime.utc_now()
    access_token = Map.get(credentials, :access_token)

    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, checkpoint} <- TranscriptCheckpoint.decode(checkpoint),
         checkpoint = TranscriptCheckpoint.expire(checkpoint, now),
         {:ok, records} <- list_records(client, checkpoint, access_token),
         {:ok, candidates} <- candidates(checkpoint, records),
         {:ok, checked} <- check_records(client, candidates, access_token) do
      {:ok,
       %{
         signals: Enum.flat_map(checked, & &1.signals),
         checkpoint:
           checkpoint
           |> TranscriptCheckpoint.advance(checked, now)
           |> TranscriptCheckpoint.encode()
       }}
    end
  end

  defp list_records(client, checkpoint, access_token) do
    params = %{
      filter: TranscriptCheckpoint.window_filter(checkpoint.watermark),
      page_size: @page_size
    }

    drain(
      fn page_token ->
        client.list_conference_records(Map.put(params, :page_token, page_token), access_token)
      end,
      @conference_records
    )
  end

  # The pending records plus the listed records the checkpoint does not know,
  # oldest end time first so signals follow the order of the meetings.
  defp candidates(checkpoint, records) do
    records
    |> Enum.reject(&TranscriptCheckpoint.known?(checkpoint, &1.conference_record_name))
    |> Enum.reduce_while({:ok, checkpoint.pending}, fn record, {:ok, acc} ->
      case TranscriptCheckpoint.parse_time(record.end_time) do
        {:ok, end_time} ->
          {:cont,
           {:ok, [%{name: record.conference_record_name, end_time: end_time, emitted: []} | acc]}}

        :error ->
          {:halt,
           Checkpoint.invalid_response(
             "Google Meet conference record list returned a record without an end time",
             %{conference_record_name: record.conference_record_name}
           )}
      end
    end)
    |> case do
      {:ok, candidates} -> {:ok, Enum.sort_by(candidates, & &1.end_time, DateTime)}
      {:error, error} -> {:error, error}
    end
  end

  defp check_records(client, candidates, access_token) do
    Enum.reduce_while(candidates, {:ok, []}, fn candidate, {:ok, acc} ->
      case check_record(client, candidate, access_token) do
        {:ok, checked} -> {:cont, {:ok, [checked | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, checked} -> {:ok, Enum.reverse(checked)}
      {:error, error} -> {:error, error}
    end
  end

  defp check_record(client, candidate, access_token) do
    params = %{conference_record_name: candidate.name, page_size: @page_size}

    fetch = fn page_token ->
      client.list_transcripts(Map.put(params, :page_token, page_token), access_token)
    end

    with {:ok, transcripts} <- drain(fetch, @transcripts) do
      ready = Enum.filter(transcripts, &ready?/1)
      fresh = Enum.reject(ready, &(&1.transcript_name in candidate.emitted))

      {:ok,
       Map.merge(candidate, %{
         emitted: candidate.emitted ++ Enum.map(fresh, & &1.transcript_name),
         settled?: transcripts != [] and length(ready) == length(transcripts),
         signals: Enum.map(fresh, &signal(candidate, &1))
       })}
    end
  end

  # Follows every page within the list's page and item bounds. A later page
  # can repeat an item under a fresh page token; the first occurrence counts.
  defp drain(fetch, list) do
    drain(fetch, list, nil, 1, [], MapSet.new(), MapSet.new())
  end

  defp drain(fetch, list, page_token, page, items, names, page_tokens) do
    with {:ok, result} <- fetch.(page_token) do
      fresh =
        result
        |> Map.get(list.resource, [])
        |> Enum.uniq_by(&Map.fetch!(&1, list.name))
        |> Enum.reject(&MapSet.member?(names, Map.fetch!(&1, list.name)))

      names = Enum.into(fresh, names, &Map.fetch!(&1, list.name))
      items = items ++ fresh
      next_page_token = Map.get(result, :next_page_token)

      cond do
        length(items) > list.max_items ->
          bound_exceeded(list, :items, list.max_items)

        is_nil(next_page_token) ->
          {:ok, items}

        MapSet.member?(page_tokens, next_page_token) ->
          Checkpoint.invalid_response("Google Meet #{list.label} repeated nextPageToken", %{
            next_page_token: next_page_token
          })

        page >= list.max_pages ->
          bound_exceeded(list, :pages, list.max_pages)

        true ->
          page_tokens = MapSet.put(page_tokens, next_page_token)
          drain(fetch, list, next_page_token, page + 1, items, names, page_tokens)
      end
    end
  end

  defp bound_exceeded(list, bound, limit) do
    {:error,
     Error.provider("Google Meet #{list.label} exceeded the poll bound of #{limit} #{bound}",
       provider: :google,
       reason: :poll_bound_exceeded,
       details: %{
         resource: list.resource,
         bound: bound,
         limit: limit,
         checkpoint_reset: Checkpoint.reset_guidance()
       }
     )}
  end

  defp ready?(%{state: "FILE_GENERATED", document_id: document_id})
       when is_binary(document_id),
       do: String.trim(document_id) != ""

  defp ready?(_transcript), do: false

  defp signal(candidate, transcript) do
    Data.compact(%{
      transcript_name: transcript.transcript_name,
      conference_record_name: candidate.name,
      document_id: transcript.document_id,
      state: transcript.state,
      start_time: transcript.start_time,
      end_time: transcript.end_time,
      export_uri: transcript.export_uri
    })
  end
end
