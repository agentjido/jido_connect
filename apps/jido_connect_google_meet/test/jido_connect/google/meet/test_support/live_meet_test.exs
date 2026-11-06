defmodule Jido.Connect.Google.Meet.TestSupport.LiveMeetTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Jido.Connect.Google.Meet.TestSupport.LiveMeet
  alias Jido.Connect.TestSupport.LiveSmoke

  require LiveMeet

  @record "conferenceRecords/tjT2Egxvkox7JrzCoRAODxIUOBEQAjIGCIoCIAAYAwg"
  @transcript @record <> "/transcripts/611a3327-9048-414c-ae74-bab9ecc3b02c"

  # The earlier conference in the prepared space, as recorded in
  # conference_records_window.2.json.
  @earlier "conferenceRecords/6EMiOc40YJH2mjvfx8U6DxIUOBEQAjIGCIoCIAAYAwg"

  @token "live-meet-test-token"

  @prepared %{
    "GOOGLE_ACCESS_TOKEN" => @token,
    "GOOGLE_MEET_CONFERENCE_RECORD" => @record,
    "GOOGLE_MEET_TRANSCRIPT" => @transcript
  }

  setup {Req.Test, :verify_on_exit!}

  setup do
    include = ExUnit.configuration()[:include]
    previous = Map.new(@prepared, fn {name, _value} -> {name, System.get_env(name)} end)

    Application.put_env(:jido_connect_google, :google_req_options,
      plug: {Req.Test, __MODULE__},
      retry: false
    )

    put_env(@prepared)
    LiveMeet.forget()

    on_exit(fn ->
      ExUnit.configure(include: include)
      Application.delete_env(:jido_connect_google, :google_req_options)
      put_env(previous)
      LiveMeet.forget()
    end)
  end

  describe "prepared!/1 outside a live run" do
    test "asks Google nothing when the run has no include filter" do
      ExUnit.configure(include: [])
      refuse_requests()

      items = [
        "GOOGLE_MEET_CONFERENCE_RECORD",
        "GOOGLE_MEET_TRANSCRIPT",
        :earlier_conference_record
      ]

      assert LiveMeet.prepared!(items) == [live_meet_prepared: items]
    end

    test "rejects an item it has no probe for, in every run" do
      ExUnit.configure(include: [])

      assert_raise ArgumentError, ~r/GOOGLE_MEET_RECORDING/, fn ->
        LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD", "GOOGLE_MEET_RECORDING"])
      end

      assert_raise ArgumentError, ~r/:later_conference_record/, fn ->
        LiveMeet.prepared!([:later_conference_record])
      end
    end
  end

  describe "prepared!/1 in a run with an include filter" do
    # An include filter overrides the :live_smoke exclude, and the tag runs
    # before ExUnit knows the test's name and describe. So every include
    # filter asks, also one that selects another test or file.
    test "asks Google, whichever filter the run includes" do
      live_smoke = "test/jido_connect/google/meet/live_smoke_test.exs"

      for include <- [
            [:live_smoke],
            [live_smoke: "true"],
            [test: "test pages through transcript entries in meeting order"],
            [describe: "google.meet.transcript.get"],
            [location: {live_smoke, 72}],
            [location: {"test/jido_connect/google/meet/other_test.exs", [3, 9]}],
            [location: live_smoke]
          ] do
        ExUnit.configure(include: include)
        LiveMeet.forget()
        serve(%{entries: "transcript_entries_not_found"})

        output =
          capture_io(fn ->
            assert LiveMeet.prepared!(["GOOGLE_MEET_TRANSCRIPT"])[:skip], inspect(include)
          end)

        assert output =~ "live_smoke skip #{Path.relative_to_cwd(__ENV__.file)}:"
        assert_received {:request, "/v2/" <> _path, _query}, inspect(include)
      end
    end
  end

  describe "prepared!/1 in a live run without what it needs" do
    setup do
      ExUnit.configure(include: [:live_smoke])
      refuse_requests()
    end

    test "asks Google nothing without an access token" do
      for token <- [nil, ""] do
        put_env(%{"GOOGLE_ACCESS_TOKEN" => token})

        assert LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD", :earlier_conference_record]) ==
                 [
                   live_meet_prepared: [
                     "GOOGLE_MEET_CONFERENCE_RECORD",
                     :earlier_conference_record
                   ]
                 ]
      end
    end

    test "asks Google nothing about an unset variable" do
      for value <- [nil, ""] do
        put_env(%{"GOOGLE_MEET_TRANSCRIPT" => value})

        assert LiveMeet.prepared!(["GOOGLE_MEET_TRANSCRIPT"]) ==
                 [live_meet_prepared: ["GOOGLE_MEET_TRANSCRIPT"]]
      end
    end
  end

  describe "prepared!/1 in a live run" do
    setup do
      ExUnit.configure(include: [:live_smoke])
    end

    test "skips on the recorded 404 of a missing transcript and names the variable" do
      serve(%{entries: "transcript_entries_not_found"})

      output =
        capture_io(fn ->
          tags = LiveMeet.prepared!(["GOOGLE_MEET_TRANSCRIPT"])

          assert tags[:live_meet_prepared] == ["GOOGLE_MEET_TRANSCRIPT"]
          assert tags[:skip] =~ "GOOGLE_MEET_TRANSCRIPT"
          assert tags[:skip] =~ "2026-10-30"
          assert tags[:skip] =~ "404 NOT_FOUND TRANSCRIPT_NOT_FOUND"
          assert tags[:skip] =~ "docs/live_smoke_tests.md"
        end)

      assert output =~
               "live_smoke skip test/jido_connect/google/meet/test_support/live_meet_test.exs:"

      assert output =~ "GOOGLE_MEET_TRANSCRIPT"
      refute output =~ @token

      assert_received {:request, path, query}
      assert path == "/v2/#{@transcript}/entries"
      assert query["pageSize"] == "1"
      refute query["fields"] =~ "text"
    end

    test "skips on the recorded 403 for a conference record that does not exist" do
      serve(%{record: "conference_record_unknown"})

      output =
        capture_io(fn ->
          reason = LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD"])[:skip]

          assert reason =~ "GOOGLE_MEET_CONFERENCE_RECORD, prepared on 2026-10-30"
          assert reason =~ "403 PERMISSION_DENIED"
          assert reason =~ "Permission denied on resource Conference (or it might not exist)"
        end)

      assert output =~
               "live_smoke skip test/jido_connect/google/meet/test_support/live_meet_test.exs:"

      assert output =~ "GOOGLE_MEET_CONFERENCE_RECORD, prepared on 2026-10-30"
      refute output =~ @token
    end

    test "skips on the recorded 403 for the entries under a record that does not exist" do
      serve(%{entries: "transcript_entries_unknown_record"})

      output =
        capture_io(fn ->
          reason = LiveMeet.prepared!(["GOOGLE_MEET_TRANSCRIPT"])[:skip]

          assert reason =~ "GOOGLE_MEET_TRANSCRIPT, prepared on 2026-10-30"
          assert reason =~ "403 PERMISSION_DENIED"
        end)

      assert output =~ "live_smoke skip "
      assert output =~ "GOOGLE_MEET_TRANSCRIPT, prepared on 2026-10-30"
    end

    test "names the first expired variable and asks nothing after it" do
      serve(%{record: "conference_record_unknown", entries: "transcript_entries_not_found"})

      capture_io(fn ->
        reason =
          LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD", "GOOGLE_MEET_TRANSCRIPT"])[:skip]

        assert reason =~ "GOOGLE_MEET_CONFERENCE_RECORD"
        refute reason =~ "GOOGLE_MEET_TRANSCRIPT"
      end)

      assert_received {:request, path, _query}
      assert path == "/v2/#{@record}"
      refute_received {:request, _path, _query}
    end

    test "leaves the test to run on the recorded 403 of a token without a Meet scope" do
      serve(%{record: "conference_record_scope_insufficient"})

      assert capture_io(fn ->
               refute LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD"])[:skip]
             end) == ""
    end

    test "leaves the test to run on the recorded answers of living data" do
      # The earlier record gets the recorded 200 of the prepared one; no
      # recording of conferenceRecords.get exists for it, and prepared!/1
      # reads only whether Google answered that the data is gone.
      serve(%{
        record: "conference_record_get_start_only",
        entries: "transcript_entries",
        earlier: "conference_record_get_start_only"
      })

      items = [
        "GOOGLE_MEET_CONFERENCE_RECORD",
        "GOOGLE_MEET_TRANSCRIPT",
        :earlier_conference_record
      ]

      output =
        capture_io(fn -> assert LiveMeet.prepared!(items) == [live_meet_prepared: items] end)

      assert output == ""
      assert_received {:request, record_path, %{"fields" => "name"}}
      assert record_path == "/v2/#{@record}"
      assert_received {:request, entries_path, _query}
      assert entries_path == "/v2/#{@transcript}/entries"
      assert_received {:request, earlier_path, %{"fields" => "name"}}
      assert earlier_path == "/v2/#{@earlier}"
    end

    test "skips on the recorded 403 for the earlier record and names that record" do
      serve(%{earlier: "conference_record_unknown"})

      output =
        capture_io(fn ->
          reason = LiveMeet.prepared!([:earlier_conference_record])[:skip]

          assert String.starts_with?(
                   reason,
                   "#{@earlier}, the earlier conference prepared on 2026-10-30 in the space " <>
                     "of GOOGLE_MEET_CONFERENCE_RECORD, has expired: Google answered 403 " <>
                     ~s(PERMISSION_DENIED "Permission denied on resource Conference ) <>
                     ~s[(or it might not exist)"]
                 )

          assert reason =~ "docs/live_smoke_tests.md"
        end)

      assert output =~
               "live_smoke skip test/jido_connect/google/meet/test_support/live_meet_test.exs:"

      assert output =~ @earlier
      refute output =~ @token

      assert_received {:request, path, %{"fields" => "name"}}
      assert path == "/v2/#{@earlier}"
    end

    # The recorded expireTime of the earlier record is 2026-11-29T16:54:56Z,
    # that of the prepared record 17:19:37Z. In between, Google answers for
    # the prepared record and its transcript as recorded, and for the earlier
    # record as for a record that does not exist.
    test "skips while only the earlier record is gone, replayed from the recordings" do
      serve(%{
        record: "conference_record_get_start_only",
        entries: "transcript_entries",
        earlier: "conference_record_unknown"
      })

      capture_io(fn ->
        reason =
          LiveMeet.prepared!([
            "GOOGLE_MEET_CONFERENCE_RECORD",
            "GOOGLE_MEET_TRANSCRIPT",
            :earlier_conference_record
          ])[:skip]

        assert String.starts_with?(reason, "#{@earlier}, the earlier conference")

        refute LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD", "GOOGLE_MEET_TRANSCRIPT"])[
                 :skip
               ]
      end)
    end

    test "names the variable once the prepared record is gone as well" do
      serve(%{record: "conference_record_unknown", earlier: "conference_record_unknown"})

      capture_io(fn ->
        reason =
          LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD", :earlier_conference_record])[:skip]

        assert String.starts_with?(
                 reason,
                 "GOOGLE_MEET_CONFERENCE_RECORD, prepared on 2026-10-30"
               )

        refute reason =~ @earlier
      end)

      assert_received {:request, path, _query}
      assert path == "/v2/#{@record}"
      refute_received {:request, _path, _query}
    end

    test "asks Google once per variable and value" do
      serve(%{entries: "transcript_entries_not_found"})

      capture_io(fn ->
        first = LiveMeet.prepared!(["GOOGLE_MEET_TRANSCRIPT"])
        assert LiveMeet.prepared!(["GOOGLE_MEET_TRANSCRIPT"])[:skip] == first[:skip]
      end)

      assert_received {:request, _path, _query}
      refute_received {:request, _path, _query}

      other = @record <> "/transcripts/00000000-0000-0000-0000-000000000000"
      put_env(%{"GOOGLE_MEET_TRANSCRIPT" => other})
      capture_io(fn -> LiveMeet.prepared!(["GOOGLE_MEET_TRANSCRIPT"]) end)

      assert_received {:request, path, _query}
      assert path == "/v2/#{other}/entries"
    end
  end

  describe "expired?/1" do
    test "reads the recorded answers for missing data as expired" do
      for {fixture, variable, name} <- [
            {"conference_record_unknown", "GOOGLE_MEET_CONFERENCE_RECORD", @record},
            {"transcript_entries_unknown_record", "GOOGLE_MEET_TRANSCRIPT", @transcript},
            {"transcript_entries_not_found", "GOOGLE_MEET_TRANSCRIPT", @transcript}
          ] do
        serve(%{record: fixture, entries: fixture})
        assert LiveMeet.expired?(LiveMeet.probe(variable, name, @token)), fixture
      end
    end

    test "reads success, a missing scope and a transport error as not expired" do
      for {fixture, variable, name} <- [
            {"conference_record_get_start_only", "GOOGLE_MEET_CONFERENCE_RECORD", @record},
            {"transcript_entries", "GOOGLE_MEET_TRANSCRIPT", @transcript},
            {"conference_record_scope_insufficient", "GOOGLE_MEET_CONFERENCE_RECORD", @record}
          ] do
        serve(%{record: fixture, entries: fixture})
        refute LiveMeet.expired?(LiveMeet.probe(variable, name, @token)), fixture
      end

      Req.Test.stub(__MODULE__, &Req.Test.transport_error(&1, :econnrefused))

      refute LiveMeet.expired?(LiveMeet.probe("GOOGLE_MEET_CONFERENCE_RECORD", @record, @token))
    end

    # Each answer below is a recorded body with exactly one field changed, so
    # that it meets one condition of the rule and fails the other.
    test "reads a 403 as expired only without a reason and with the message of a missing record" do
      unknown = LiveSmoke.fixture!(:google_meet, "conference_record_unknown")
      scoped = LiveSmoke.fixture!(:google_meet, "conference_record_scope_insufficient")

      for {label, body} <- [
            # conference_record_scope_insufficient, its message replaced by
            # that of conference_record_unknown: an ErrorInfo reason, but the
            # message says the resource might not exist.
            {"reason with might-not-exist message",
             put_in(scoped, ["error", "message"], unknown["error"]["message"])},
            # conference_record_unknown, its message replaced by that of
            # conference_record_scope_insufficient: no ErrorInfo reason, but
            # another message.
            {"no reason with another message",
             put_in(unknown, ["error", "message"], scoped["error"]["message"])}
          ] do
        serve(%{record: body})

        refute LiveMeet.expired?(
                 LiveMeet.probe("GOOGLE_MEET_CONFERENCE_RECORD", @record, @token)
               ),
               label
      end
    end

    test "reads a 404 as expired only with error.status NOT_FOUND" do
      # transcript_entries_not_found without its error.status.
      body =
        :google_meet
        |> LiveSmoke.fixture!("transcript_entries_not_found")
        |> update_in(["error"], &Map.delete(&1, "status"))

      serve(%{entries: body})

      assert {:ok, %{status: 404}} =
               result = LiveMeet.probe("GOOGLE_MEET_TRANSCRIPT", @transcript, @token)

      refute LiveMeet.expired?(result)
    end
  end

  # Serves recorded responses by request: `:earlier` for conferenceRecords.get
  # of the earlier record, `:record` for that of any other record, `:entries`
  # for transcripts.entries.list. A value names a recorded fixture or is a
  # body built from one. The status comes from the body's `error.code`, as in
  # the client tests, and is 200 without one.
  defp serve(fixtures) do
    test = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test, {:request, conn.request_path, URI.decode_query(conn.query_string)})
      body = fixtures |> Map.fetch!(kind(conn.request_path)) |> body()

      conn
      |> Plug.Conn.put_status(get_in(body, ["error", "code"]) || 200)
      |> Req.Test.json(body)
    end)
  end

  defp body(fixture) when is_binary(fixture), do: LiveSmoke.fixture!(:google_meet, fixture)
  defp body(body) when is_map(body), do: body

  defp kind("/v2/" <> @earlier), do: :earlier

  defp kind(path) do
    if String.ends_with?(path, "/entries"), do: :entries, else: :record
  end

  defp refuse_requests do
    Req.Test.stub(__MODULE__, fn conn ->
      flunk("prepared!/1 asked Google for #{conn.request_path}")
    end)
  end

  defp put_env(values) do
    Enum.each(values, fn
      {name, nil} -> System.delete_env(name)
      {name, value} -> System.put_env(name, value)
    end)
  end
end
