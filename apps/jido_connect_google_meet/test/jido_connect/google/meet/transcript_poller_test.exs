defmodule Jido.Connect.Google.Meet.TranscriptPollerTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.Error.{ProviderError, ValidationError}
  alias Jido.Connect.Google.Meet
  alias Jido.Connect.TestSupport.LiveSmoke

  @trigger_id "google.meet.transcript.available"
  @readonly_scope "https://www.googleapis.com/auth/meetings.space.readonly"

  # The recorded conference records ended at 16:54:56 and 17:19:37 UTC.
  @before_recorded ~U[2026-10-30 16:00:00Z]

  @reset %{action: :clear_checkpoint, behavior: :initialize_without_replay}

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_google_meet, :google_meet_api_base_url, "https://meet.test")
    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_google_meet, :google_meet_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  describe "first poll" do
    test "an empty checkpoint emits nothing and starts the watermark at the poll time" do
      for empty <- [nil, ""] do
        started = DateTime.utc_now()

        assert {:ok, %{signals: [], checkpoint: checkpoint}} = poll(empty)

        assert %{
                 "version" => 1,
                 "watermark" => watermark,
                 "settled" => [],
                 "pending" => []
               } = JSON.decode!(checkpoint)

        assert {:ok, watermark, 0} = DateTime.from_iso8601(watermark)
        assert DateTime.compare(watermark, started) != :lt
        assert DateTime.compare(watermark, DateTime.utc_now()) != :gt
      end
    end
  end

  describe "watermark window" do
    test "a watermark before the recorded records drains both pages and emits each transcript once" do
      [first_page, second_page] = recorded_record_pages()
      [prepared] = first_page["conferenceRecords"]
      [earlier] = second_page["conferenceRecords"]
      [prepared_transcript] = fixture("transcripts")["transcripts"]
      [earlier_transcript] = fixture("transcripts_earlier_record")["transcripts"]

      serve(
        records: pages([first_page, second_page]),
        transcripts: %{
          prepared["name"] => pages([fixture("transcripts")]),
          earlier["name"] => pages([fixture("transcripts_earlier_record")])
        }
      )

      assert {:ok, %{signals: [earlier_signal, prepared_signal], checkpoint: checkpoint}} =
               poll(checkpoint(@before_recorded))

      assert earlier_signal == expected_signal(earlier, earlier_transcript)
      assert prepared_signal == expected_signal(prepared, prepared_transcript)

      assert JSON.decode!(checkpoint) == %{
               "version" => 1,
               "watermark" => prepared["endTime"],
               "settled" => [settled_entry(prepared)],
               "pending" => []
             }
    end
  end

  describe "repeat and new records" do
    test "a repeat with the returned checkpoint emits nothing and lists no transcripts" do
      [prepared, earlier] = recorded_records()

      serve(
        records: pages(recorded_record_pages()),
        transcripts: %{
          prepared["name"] => pages([fixture("transcripts")]),
          earlier["name"] => pages([fixture("transcripts_earlier_record")])
        }
      )

      assert {:ok, %{signals: [_earlier, _prepared], checkpoint: checkpoint}} =
               poll(checkpoint(@before_recorded))

      serve(records: {:window, recorded_records()})

      assert {:ok, %{signals: [], checkpoint: repeated}} = poll(checkpoint)
      assert JSON.decode!(repeated) == JSON.decode!(checkpoint)
    end

    test "a pending and a new record generated in one poll signal in end time order" do
      [prepared, _earlier] = recorded_records()
      now = DateTime.utc_now()
      older = record_at(prepared, "older", DateTime.add(now, -3, :hour))
      newer = record_at(prepared, "newer", DateTime.add(now, -1, :hour))
      [older_transcript] = transcripts_for(older)["transcripts"]
      [newer_transcript] = transcripts_for(newer)["transcripts"]

      serve(
        records: {:window, [older, newer]},
        transcripts: %{
          older["name"] => pages([transcripts_for(older)]),
          newer["name"] => pages([transcripts_for(newer)])
        }
      )

      checkpoint =
        checkpoint(time!(older["endTime"]), [], [pending_entry(older["name"], older["endTime"])])

      assert {:ok, %{signals: signals}} = poll(checkpoint)

      assert signals == [
               expected_signal(older, older_transcript),
               expected_signal(newer, newer_transcript)
             ]
    end

    test "a record ending after the watermark is picked up" do
      [prepared, earlier] = recorded_records()
      [prepared_transcript] = fixture("transcripts")["transcripts"]

      serve(
        records: {:window, recorded_records()},
        transcripts: %{prepared["name"] => pages([fixture("transcripts")])}
      )

      watermark = time!(earlier["endTime"])

      assert {:ok, %{signals: [signal], checkpoint: checkpoint}} =
               poll(checkpoint(watermark, [settled_entry(earlier)]))

      assert signal == expected_signal(prepared, prepared_transcript)

      assert %{"watermark" => watermark, "settled" => [settled], "pending" => []} =
               JSON.decode!(checkpoint)

      assert {watermark, settled} == {prepared["endTime"], settled_entry(prepared)}
    end
  end

  describe "watermark behind pending records" do
    test "a record listed after a later pending record is still emitted" do
      now = DateTime.utc_now()
      [prepared, _earlier] = recorded_records()
      watermark = DateTime.add(now, -3, :hour)
      a = record_at(prepared, "a", DateTime.add(now, -2, :hour))
      b = record_at(prepared, "b", DateTime.add(now, -1, :hour))
      [a_transcript] = transcripts_for(a)["transcripts"]
      [b_transcript] = transcripts_for(b)["transcripts"]
      b_not_ready = with_state(transcripts_for(b), "ENDED")
      b_pending = pending_entry(b["name"], b["endTime"])

      # B is listed first; A, which ended earlier, is not visible yet.
      serve(records: {:window, [b]}, transcripts: %{b["name"] => pages([b_not_ready])})

      assert {:ok, %{signals: [], checkpoint: checkpoint}} = poll(checkpoint(watermark))
      assert JSON.decode!(checkpoint) == JSON.decode!(checkpoint(watermark, [], [b_pending]))

      serve(
        records: {:window, [a, b]},
        transcripts: %{
          a["name"] => pages([transcripts_for(a)]),
          b["name"] => pages([b_not_ready])
        }
      )

      assert {:ok, %{signals: [signal], checkpoint: checkpoint}} = poll(checkpoint)
      assert signal == expected_signal(a, a_transcript)

      assert JSON.decode!(checkpoint) ==
               JSON.decode!(checkpoint(time!(a["endTime"]), [settled_entry(a)], [b_pending]))

      assert {:ok, %{signals: [], checkpoint: ^checkpoint}} = poll(checkpoint)

      # B's transcript is generated later; the watermark moves on to B.
      serve(
        records: {:window, [a, b]},
        transcripts: %{b["name"] => pages([transcripts_for(b)])}
      )

      assert {:ok, %{signals: [signal], checkpoint: checkpoint}} = poll(checkpoint)
      assert signal == expected_signal(b, b_transcript)

      assert JSON.decode!(checkpoint) ==
               JSON.decode!(checkpoint(time!(b["endTime"]), [settled_entry(b)]))

      assert {:ok, %{signals: [], checkpoint: ^checkpoint}} = poll(checkpoint)
    end
  end

  describe "transcript readiness" do
    for {label, derive} <- [
          {"STARTED", quote(do: &with_state(&1, "STARTED"))},
          {"ENDED", quote(do: &with_state(&1, "ENDED"))},
          {"an unknown state", quote(do: &with_state(&1, "STATE_UNSPECIFIED"))},
          {"a missing document_id", quote(do: &without_document/1)},
          {"no transcript yet", quote(do: fn _body -> empty_page() end)}
        ] do
      test "#{label} emits nothing until the transcript is generated, then once" do
        prepared = recent_prepared_record()
        [prepared_transcript] = fixture("transcripts")["transcripts"]
        not_ready = unquote(derive).(fixture("transcripts"))
        watermark = time!(prepared["endTime"])

        serve(
          records: {:window, [prepared]},
          transcripts: %{prepared["name"] => pages([not_ready])}
        )

        assert {:ok, %{signals: [], checkpoint: checkpoint}} = poll(checkpoint(watermark))

        assert %{"pending" => [%{"name" => pending, "emitted" => []}]} =
                 JSON.decode!(checkpoint)

        assert pending == prepared["name"]

        assert {:ok, %{signals: [], checkpoint: ^checkpoint}} = poll(checkpoint)

        serve(
          records: {:window, [prepared]},
          transcripts: %{prepared["name"] => pages([fixture("transcripts")])}
        )

        assert {:ok, %{signals: [signal], checkpoint: checkpoint}} = poll(checkpoint)
        assert signal == expected_signal(prepared, prepared_transcript)
        assert {:ok, _signal} = Zoi.parse(signal_schema(), signal)

        assert JSON.decode!(checkpoint) ==
                 JSON.decode!(checkpoint(watermark, [settled_entry(prepared)]))

        assert {:ok, %{signals: [], checkpoint: ^checkpoint}} = poll(checkpoint)
      end
    end

    test "a record with one generated and one ended transcript emits each transcript once" do
      [_prepared, earlier] = recorded_records()
      prepared = recent_prepared_record()
      [prepared_transcript] = fixture("transcripts")["transcripts"]
      second = second_transcript(prepared, earlier)
      [second_transcript] = second["transcripts"]
      first_ready = combined(fixture("transcripts"), with_state(second, "ENDED"))
      both_ready = combined(fixture("transcripts"), second)

      serve(
        records: {:window, [prepared]},
        transcripts: %{prepared["name"] => pages([first_ready])}
      )

      assert {:ok, %{signals: [signal], checkpoint: checkpoint}} =
               poll(checkpoint(time!(prepared["endTime"])))

      assert signal == expected_signal(prepared, prepared_transcript)

      assert %{"pending" => [%{"emitted" => [emitted]}]} = JSON.decode!(checkpoint)
      assert emitted == prepared_transcript["name"]

      assert {:ok, %{signals: [], checkpoint: ^checkpoint}} = poll(checkpoint)

      serve(
        records: {:window, [prepared]},
        transcripts: %{prepared["name"] => pages([both_ready])}
      )

      assert {:ok, %{signals: [signal], checkpoint: checkpoint}} = poll(checkpoint)
      assert signal == expected_signal(prepared, second_transcript)
      assert %{"pending" => [], "settled" => [_settled]} = JSON.decode!(checkpoint)
    end
  end

  describe "pages" do
    test "transcripts are drained across pages" do
      [prepared, earlier] = recorded_records()
      [prepared_transcript] = fixture("transcripts")["transcripts"]
      second = second_transcript(prepared, earlier)
      [second_transcript] = second["transcripts"]

      serve(
        records: {:window, recorded_records()},
        transcripts: %{
          prepared["name"] =>
            pages([Map.put(fixture("transcripts"), "nextPageToken", "transcripts-2"), second])
        }
      )

      assert {:ok, %{signals: signals, checkpoint: checkpoint}} =
               poll(checkpoint(time!(prepared["endTime"])))

      assert signals == [
               expected_signal(prepared, prepared_transcript),
               expected_signal(prepared, second_transcript)
             ]

      assert %{"pending" => [], "settled" => [settled]} = JSON.decode!(checkpoint)
      assert settled == settled_entry(prepared)
    end

    test "a later page that repeats a record is drained without a second signal" do
      [first_page, second_page] = recorded_record_pages()
      [prepared, earlier] = recorded_records()
      repeated = Map.put(first_page, "nextPageToken", "repeated-first-page")

      serve(
        records: %{
          nil => first_page,
          first_page["nextPageToken"] => repeated,
          "repeated-first-page" => second_page
        },
        transcripts: %{
          prepared["name"] => pages([fixture("transcripts")]),
          earlier["name"] => pages([fixture("transcripts_earlier_record")])
        }
      )

      assert {:ok, %{signals: [_earlier, _prepared]}} = poll(checkpoint(@before_recorded))
    end

    test "a page that repeats a record yields one signal" do
      [first_page, _second_page] = recorded_record_pages()
      [prepared] = first_page["conferenceRecords"]
      [prepared_transcript] = fixture("transcripts")["transcripts"]
      repeated = %{"conferenceRecords" => [prepared, prepared]}

      serve(
        records: pages([repeated]),
        transcripts: %{prepared["name"] => pages([fixture("transcripts")])}
      )

      assert {:ok, %{signals: [signal]}} = poll(checkpoint(@before_recorded))
      assert signal == expected_signal(prepared, prepared_transcript)
    end
  end

  describe "no partial success" do
    test "a repeated record page token returns an error and no checkpoint" do
      [first_page, second_page] = recorded_record_pages()
      looping = Map.put(second_page, "nextPageToken", first_page["nextPageToken"])

      serve(records: pages([first_page, looping]))

      assert {:error, %ProviderError{reason: :invalid_response, details: details}} =
               poll(checkpoint(@before_recorded))

      assert details.next_page_token == first_page["nextPageToken"]
      assert details.checkpoint_reset == @reset
    end

    test "a repeated transcript page token returns an error and no checkpoint" do
      [prepared, earlier] = recorded_records()
      first_page = Map.put(fixture("transcripts"), "nextPageToken", "transcripts-2")

      looping =
        prepared |> second_transcript(earlier) |> Map.put("nextPageToken", "transcripts-2")

      serve(
        records: {:window, recorded_records()},
        transcripts: %{prepared["name"] => pages([first_page, looping])}
      )

      assert {:error, %ProviderError{reason: :invalid_response, details: details}} =
               poll(checkpoint(time!(prepared["endTime"])))

      assert details.next_page_token == "transcripts-2"
      assert details.checkpoint_reset == @reset
    end

    test "more than 10 conference record pages return an error and no checkpoint" do
      [first_page, _second_page] = recorded_record_pages()

      # The eleventh page ends the listing; the poll must stop before it.
      serve(records: pages(record_pages(first_page, 11, 1)))

      assert {:error, %ProviderError{reason: :poll_bound_exceeded, details: details}} =
               poll(checkpoint(@before_recorded))

      assert %{resource: :conference_records, bound: :pages, limit: 10} = details
      assert details.checkpoint_reset == @reset
    end

    test "10 pages with 100 conference records in total are accepted" do
      [first_page, _second_page] = recorded_record_pages()
      record_pages = record_pages(first_page, 10, 10)
      names = for page <- record_pages, record <- page["conferenceRecords"], do: record["name"]

      serve(
        records: pages(record_pages),
        transcripts: Map.new(names, &{&1, pages([empty_page()])})
      )

      assert {:ok, %{signals: [], checkpoint: checkpoint}} = poll(checkpoint(@before_recorded))
      assert %{"settled" => settled} = JSON.decode!(checkpoint)
      assert length(settled) == 100
    end

    test "more than 100 conference records across pages return an error and no checkpoint" do
      [first_page, _second_page] = recorded_record_pages()

      serve(records: pages(record_pages(first_page, 2, 51)))

      assert {:error, %ProviderError{reason: :poll_bound_exceeded, details: details}} =
               poll(checkpoint(@before_recorded))

      assert %{resource: :conference_records, bound: :items, limit: 100} = details
    end

    test "more than 100 conference records return an error and no checkpoint" do
      [first_page, _second_page] = recorded_record_pages()
      [record] = first_page["conferenceRecords"]
      page = %{"conferenceRecords" => Enum.map(1..101, &renamed(record, &1))}

      serve(records: pages([page]))

      assert {:error, %ProviderError{reason: :poll_bound_exceeded, details: details}} =
               poll(checkpoint(@before_recorded))

      assert %{resource: :conference_records, bound: :items, limit: 100} = details
    end

    test "more than 5 transcript pages for a record return an error and no checkpoint" do
      [prepared, _earlier] = recorded_records()

      transcript_pages =
        for n <- 1..6 do
          fixture("transcripts")
          |> update_transcripts(&renamed(&1, n))
          |> Map.put("nextPageToken", "transcripts-#{n + 1}")
        end

      serve(
        records: {:window, recorded_records()},
        transcripts: %{prepared["name"] => pages(transcript_pages)}
      )

      assert {:error, %ProviderError{reason: :poll_bound_exceeded, details: details}} =
               poll(checkpoint(time!(prepared["endTime"])))

      assert %{resource: :transcripts, bound: :pages, limit: 5} = details
    end

    test "more than 25 transcripts for a record return an error and no checkpoint" do
      [prepared, _earlier] = recorded_records()
      [transcript] = fixture("transcripts")["transcripts"]
      page = %{"transcripts" => Enum.map(1..26, &renamed(transcript, &1))}

      serve(
        records: {:window, recorded_records()},
        transcripts: %{prepared["name"] => pages([page])}
      )

      assert {:error, %ProviderError{reason: :poll_bound_exceeded, details: details}} =
               poll(checkpoint(time!(prepared["endTime"])))

      assert %{resource: :transcripts, bound: :items, limit: 25} = details
    end

    test "a failed later conference record page returns the error and no checkpoint" do
      [first_page, _second_page] = recorded_record_pages()

      serve(
        records: %{
          nil => first_page,
          first_page["nextPageToken"] => {404, fixture("transcript_entries_not_found")}
        }
      )

      assert {:error, %ProviderError{status: 404}} = poll(checkpoint(@before_recorded))
    end

    test "a failed later transcript page returns the error and no checkpoint" do
      [prepared, _earlier] = recorded_records()
      first_page = Map.put(fixture("transcripts"), "nextPageToken", "transcripts-2")

      serve(
        records: {:window, recorded_records()},
        transcripts: %{
          prepared["name"] => %{
            nil => first_page,
            "transcripts-2" => {404, fixture("transcript_entries_not_found")}
          }
        }
      )

      assert {:error, %ProviderError{status: 404}} = poll(checkpoint(time!(prepared["endTime"])))
    end
  end

  describe "checkpoint bounds" do
    test "the pending set keeps the 50 most recent records; the dropped one moves the watermark" do
      [prepared, _earlier] = recorded_records()
      now = DateTime.utc_now()
      watermark = DateTime.add(now, -61, :minute)

      pending =
        for n <- 1..50 do
          pending_entry("#{prepared["name"]}-#{n}", DateTime.add(now, -(10 + n), :minute))
        end

      new_record = record_at(prepared, "new", DateTime.add(now, -1, :minute))
      names = [new_record["name"] | Enum.map(pending, & &1["name"])]
      not_ready = with_state(fixture("transcripts"), "ENDED")

      serve(
        records: {:window, [new_record]},
        transcripts: Map.new(names, &{&1, pages([not_ready])})
      )

      assert {:ok, %{signals: [], checkpoint: checkpoint}} =
               poll(checkpoint(watermark, [], pending))

      assert %{"watermark" => watermark, "pending" => kept, "settled" => [dropped]} =
               JSON.decode!(checkpoint)

      assert Enum.map(kept, & &1["name"]) == Enum.take(names, 50)

      oldest = List.last(pending)
      assert dropped == settled_entry(oldest["name"], oldest["end_time"])
      assert watermark == oldest["end_time"]
    end

    test "a pending record older than 24 hours leaves the pending set and releases the watermark" do
      [prepared, _earlier] = recorded_records()
      now = DateTime.utc_now()
      aged = record_at(prepared, "aged", DateTime.add(now, -25, :hour))
      settled = record_at(prepared, "settled", DateTime.add(now, -24, :hour))
      fresh = record_at(prepared, "fresh", DateTime.add(now, -23, :hour))
      not_ready = with_state(fixture("transcripts"), "ENDED")

      serve(
        records: {:window, [settled, fresh]},
        transcripts: %{fresh["name"] => pages([not_ready])}
      )

      # The aged record held the watermark at its end time.
      checkpoint =
        checkpoint(time!(aged["endTime"]), [settled_entry(settled)], [
          pending_entry(fresh["name"], fresh["endTime"]),
          pending_entry(aged["name"], aged["endTime"])
        ])

      assert {:ok, %{signals: [], checkpoint: checkpoint}} = poll(checkpoint)

      assert JSON.decode!(checkpoint) ==
               JSON.decode!(
                 checkpoint(time!(settled["endTime"]), [settled_entry(settled)], [
                   pending_entry(fresh["name"], fresh["endTime"])
                 ])
               )
    end

    test "a pending record past the age bound is not checked again, even when generated" do
      [prepared, _earlier] = recorded_records()
      aged = record_at(prepared, "aged", DateTime.add(DateTime.utc_now(), -25, :hour))
      watermark = time!(aged["endTime"])

      serve(
        records: {:window, [aged]},
        transcripts: %{aged["name"] => pages([transcripts_for(aged)])}
      )

      assert {:ok, %{signals: [], checkpoint: checkpoint}} =
               poll(checkpoint(watermark, [], [pending_entry(aged["name"], watermark)]))

      assert JSON.decode!(checkpoint) ==
               JSON.decode!(checkpoint(watermark, [settled_entry(aged)]))

      serve(records: {:window, [aged]})

      assert {:ok, %{signals: [], checkpoint: ^checkpoint}} = poll(checkpoint)
    end

    test "a pending record whose conference record was deleted does not block the poll" do
      [prepared, _earlier] = recorded_records()
      now = DateTime.utc_now()
      # Google deletes a conference record 30 days after the conference ended.
      deleted = record_at(prepared, "deleted", DateTime.add(now, -31, :day))
      fresh = record_at(prepared, "fresh", DateTime.add(now, -1, :hour))
      [fresh_transcript] = transcripts_for(fresh)["transcripts"]

      serve(
        records: {:window, [fresh]},
        transcripts: %{
          deleted["name"] => %{nil => {404, fixture("transcript_entries_not_found")}},
          fresh["name"] => pages([transcripts_for(fresh)])
        }
      )

      checkpoint =
        checkpoint(time!(deleted["endTime"]), [], [
          pending_entry(deleted["name"], deleted["endTime"])
        ])

      assert {:ok, %{signals: [signal], checkpoint: checkpoint}} = poll(checkpoint)
      assert signal == expected_signal(fresh, fresh_transcript)

      assert JSON.decode!(checkpoint) ==
               JSON.decode!(checkpoint(time!(fresh["endTime"]), [settled_entry(fresh)]))
    end

    test "a newly listed record older than 24 hours is checked once and not kept" do
      [prepared, _earlier] = recorded_records()
      not_ready = with_state(fixture("transcripts"), "ENDED")

      serve(
        records: {:window, [prepared]},
        transcripts: %{prepared["name"] => pages([not_ready])}
      )

      assert {:ok, %{signals: [], checkpoint: checkpoint}} = poll(checkpoint(@before_recorded))

      assert JSON.decode!(checkpoint) ==
               JSON.decode!(checkpoint(time!(prepared["endTime"]), [settled_entry(prepared)]))
    end
  end

  describe "invalid input" do
    test "an invalid checkpoint returns reset guidance without calling Google" do
      valid = JSON.decode!(checkpoint(@before_recorded))

      for invalid <- [
            "not json",
            JSON.encode!(Map.put(valid, "version", 2)),
            JSON.encode!(Map.delete(valid, "pending")),
            JSON.encode!(Map.put(valid, "watermark", "yesterday")),
            JSON.encode!(Map.put(valid, "settled", [1])),
            JSON.encode!(Map.put(valid, "settled", [settled_entry("abc", "yesterday")])),
            JSON.encode!(Map.put(valid, "pending", [%{"name" => "conferenceRecords/abc"}])),
            JSON.encode!(Map.put(valid, "pending", [pending_entry("abc", "yesterday")])),
            JSON.encode!(
              Map.put(valid, "pending", [
                Map.put(pending_entry("abc", @before_recorded), "emitted", [1])
              ])
            ),
            JSON.encode!(Map.put(valid, "pending", nil)),
            valid
          ] do
        assert {:error,
                %ValidationError{
                  reason: :invalid_checkpoint,
                  details: %{checkpoint_reset: @reset}
                }} = poll(invalid)
      end
    end

    test "a listed conference record without an end time returns an error" do
      [first_page, _second_page] = recorded_record_pages()

      without_end_time =
        Map.update!(first_page, "conferenceRecords", fn records ->
          Enum.map(records, &Map.delete(&1, "endTime"))
        end)

      serve(records: pages([Map.delete(without_end_time, "nextPageToken")]))

      assert {:error, %ProviderError{reason: :invalid_response, details: details}} =
               poll(checkpoint(@before_recorded))

      assert details.checkpoint_reset == @reset
    end
  end

  defp expected_signal(record, transcript) do
    %{
      transcript_name: transcript["name"],
      conference_record_name: record["name"],
      document_id: transcript["docsDestination"]["document"],
      state: transcript["state"],
      start_time: transcript["startTime"],
      end_time: transcript["endTime"],
      export_uri: transcript["docsDestination"]["exportUri"]
    }
  end

  defp fixture(name), do: LiveSmoke.fixture!(:google_meet, name)

  defp recorded_record_pages do
    [fixture("conference_records_window"), fixture("conference_records_window.2")]
  end

  defp recorded_records do
    Enum.flat_map(recorded_record_pages(), & &1["conferenceRecords"])
  end

  # Google answers an empty list with an empty object, as recorded for an
  # empty conference record window.
  defp empty_page, do: fixture("conference_records_window_empty")

  defp with_state(body, state) do
    update_transcripts(body, &Map.put(&1, "state", state))
  end

  defp without_document(body) do
    update_transcripts(body, fn transcript ->
      Map.update!(transcript, "docsDestination", &Map.delete(&1, "document"))
    end)
  end

  # The earlier record's recorded transcript, moved under `record`, stands in
  # for a second transcription session of the same meeting.
  defp second_transcript(record, earlier) do
    update_transcripts(fixture("transcripts_earlier_record"), fn transcript ->
      Map.update!(transcript, "name", &String.replace(&1, earlier["name"], record["name"]))
    end)
  end

  # The recorded transcript of the prepared record, moved under `record`.
  defp transcripts_for(record) do
    [prepared, _earlier] = recorded_records()

    update_transcripts(fixture("transcripts"), fn transcript ->
      Map.update!(transcript, "name", &String.replace(&1, prepared["name"], record["name"]))
    end)
  end

  defp combined(body, other) do
    Map.update!(body, "transcripts", &(&1 ++ other["transcripts"]))
  end

  # The recorded prepared record as if its meeting had ended an hour ago,
  # well inside the 24 hour age bound of the pending set.
  defp recent_prepared_record do
    [prepared, _earlier] = recorded_records()
    end_time = DateTime.add(DateTime.utc_now(), -1, :hour)
    Map.put(prepared, "endTime", DateTime.to_iso8601(end_time))
  end

  defp record_at(record, suffix, end_time) do
    record
    |> renamed(suffix)
    |> Map.put("endTime", DateTime.to_iso8601(end_time))
  end

  defp pending_entry(name, end_time) when is_binary(end_time),
    do: %{"name" => name, "end_time" => end_time, "emitted" => []}

  defp pending_entry(name, end_time), do: pending_entry(name, DateTime.to_iso8601(end_time))

  defp settled_entry(record), do: settled_entry(record["name"], record["endTime"])

  defp settled_entry(name, end_time), do: %{"name" => name, "end_time" => end_time}

  # `count` pages of `per_page` renamed copies of the page's record, linked by
  # page tokens; the last page ends the listing.
  defp record_pages(page, count, per_page) do
    [record] = page["conferenceRecords"]

    for n <- 1..count do
      records = for m <- 1..per_page, do: renamed(record, "#{n}-#{m}")
      body = %{"conferenceRecords" => records}
      if n < count, do: Map.put(body, "nextPageToken", "records-#{n + 1}"), else: body
    end
  end

  defp renamed(resource, n), do: Map.update!(resource, "name", &"#{&1}-#{n}")

  defp update_transcripts(body, fun), do: Map.update!(body, "transcripts", &Enum.map(&1, fun))

  defp signal_schema do
    {:ok, trigger} = Connect.trigger(Meet.integration(), @trigger_id)
    trigger.signal_schema
  end

  defp time!(value) do
    {:ok, time, 0} = DateTime.from_iso8601(value)
    time
  end

  defp checkpoint(watermark, settled \\ [], pending \\ []) do
    JSON.encode!(%{
      "version" => 1,
      "watermark" => DateTime.to_iso8601(watermark),
      "settled" => settled,
      "pending" => pending
    })
  end

  # Maps each page token to the page it opens, the first page under nil.
  defp pages(bodies) do
    tokens = [nil | Enum.map(bodies, & &1["nextPageToken"])]
    tokens |> Enum.zip(bodies) |> Map.new()
  end

  # Serves recorded bodies like the Meet API. Record pages are looked up by
  # page token; transcript pages by conference record and page token. A value
  # `{status, body}` answers with that status.
  defp serve(opts) do
    records = Keyword.fetch!(opts, :records)
    transcripts = Keyword.get(opts, :transcripts, %{})

    Req.Test.stub(__MODULE__, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      assert conn.query_params["pageSize"] == "100"
      token = conn.query_params["pageToken"]

      case String.split(conn.request_path, "/transcripts") do
        ["/v2/conferenceRecords"] ->
          respond(conn, record_page(records, conn.query_params["filter"], token))

        ["/v2/" <> record, ""] ->
          respond(conn, transcripts |> Map.fetch!(record) |> Map.fetch!(token))
      end
    end)
  end

  # `{:window, records}` answers like the provider: one page with the records
  # whose end time is at or after the filter's watermark.
  defp record_page({:window, records}, filter, nil) do
    assert [_filter, watermark] =
             Regex.run(~r/\Aend_time>="([^"]+)" AND start_time>="1970-01-01T00:00:00Z"\z/, filter)

    watermark = time!(watermark)

    case Enum.filter(records, &(DateTime.compare(time!(&1["endTime"]), watermark) != :lt)) do
      [] -> empty_page()
      matches -> %{"conferenceRecords" => matches}
    end
  end

  defp record_page(pages, filter, token) do
    assert filter =~ ~r/\Aend_time>="[^"]+" AND start_time>="1970-01-01T00:00:00Z"\z/
    Map.fetch!(pages, token)
  end

  defp respond(conn, {status, body}),
    do: conn |> Plug.Conn.put_status(status) |> Req.Test.json(body)

  defp respond(conn, body), do: Req.Test.json(conn, body)

  defp poll(checkpoint) do
    Connect.poll(Meet.integration(), @trigger_id, %{},
      context: context(),
      credential_lease: lease(),
      checkpoint: checkpoint
    )
  end

  defp context do
    Connect.Context.new!(%{
      tenant_id: "tenant_1",
      actor: %{id: "user_1", type: :user},
      connection:
        Connect.Connection.new!(%{
          id: "conn_1",
          provider: :google,
          profile: :user,
          tenant_id: "tenant_1",
          owner_type: :app_user,
          owner_id: "user_1",
          status: :connected,
          scopes: [@readonly_scope]
        })
    })
  end

  defp lease do
    Connect.CredentialLease.new!(%{
      connection_id: "conn_1",
      provider: :google,
      profile: :user,
      expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
      fields: %{access_token: "token"},
      scopes: [@readonly_scope]
    })
  end
end
