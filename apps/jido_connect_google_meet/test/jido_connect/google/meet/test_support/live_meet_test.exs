defmodule Jido.Connect.Google.Meet.TestSupport.LiveMeetTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Jido.Connect.Google.Meet.TestSupport.LiveMeet
  alias Jido.Connect.TestSupport.LiveSmoke

  require LiveMeet

  @record "conferenceRecords/tjT2Egxvkox7JrzCoRAODxIUOBEQAjIGCIoCIAAYAwg"
  @transcript @record <> "/transcripts/611a3327-9048-414c-ae74-bab9ecc3b02c"
  @both ["GOOGLE_MEET_CONFERENCE_RECORD", "GOOGLE_MEET_TRANSCRIPT"]

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

    on_exit(fn ->
      ExUnit.configure(include: include)
      Application.delete_env(:jido_connect_google, :google_req_options)
      put_env(previous)
    end)
  end

  describe "prepared!/1 outside a live run" do
    test "asks Google nothing when the run does not include live tests" do
      ExUnit.configure(include: [])
      refuse_requests()

      assert LiveMeet.prepared!(@both) == [live_meet_prepared: @both]
    end

    test "rejects a variable it has no probe for, in every run" do
      ExUnit.configure(include: [])

      for variable <- ["GOOGLE_ACCESS_TOKEN", "GOOGLE_MEET_RECORDING"] do
        assert_raise ArgumentError, ~r/#{variable}/, fn ->
          LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD", variable])
        end
      end
    end

    test "asks Google about a test of the file that a location filter names" do
      ExUnit.configure(include: [location: {"test/jido_connect/google/meet/other_test.exs", 3}])
      refuse_requests()
      assert LiveMeet.prepared!(["GOOGLE_MEET_TRANSCRIPT"])[:skip] == nil

      file = Path.relative_to_cwd(__ENV__.file)
      ExUnit.configure(include: [location: {file, __ENV__.line}])
      serve(%{entries: "transcript_entries_not_found"})

      output = capture_io(fn -> assert LiveMeet.prepared!(["GOOGLE_MEET_TRANSCRIPT"])[:skip] end)

      assert output =~ "live_smoke skip #{file}:"
      assert_received {:request, "/v2/" <> _path, _query}
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

        assert LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD"]) ==
                 [live_meet_prepared: ["GOOGLE_MEET_CONFERENCE_RECORD"]]
      end
    end

    test "asks Google nothing about an unset variable, which env!/1 skips" do
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
          assert tags[:skip] =~ "GOOGLE_MEET_TRANSCRIPT, prepared on 2026-10-30"
          assert tags[:skip] =~ "404 NOT_FOUND TRANSCRIPT_NOT_FOUND"
          refute tags[:skip] =~ @transcript
        end)

      assert output =~
               "live_smoke skip test/jido_connect/google/meet/test_support/live_meet_test.exs:"

      assert output =~ "404 NOT_FOUND TRANSCRIPT_NOT_FOUND"
      refute output =~ @token

      assert_received {:request, path, query}
      assert path == "/v2/#{@transcript}/entries"
      assert query["pageSize"] == "1"
      refute query["fields"] =~ "text"
    end

    test "skips on the recorded 403 for a conference record that does not exist" do
      # Google's answer for the deleted record cannot be seen before 2026-11-29.
      # This 403 was recorded on 2026-11-06 for a well-formed record ID that
      # names no conference the test user can see, the state of a deleted record.
      serve(%{record: "conference_record_unknown"})

      output =
        capture_io(fn ->
          tags = LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD"])

          assert tags[:live_meet_prepared] == ["GOOGLE_MEET_CONFERENCE_RECORD"]
          assert tags[:skip] =~ "GOOGLE_MEET_CONFERENCE_RECORD, prepared on 2026-10-30"

          assert tags[:skip] =~
                   ~s|403 PERMISSION_DENIED "Permission denied on resource Conference (or it might not exist)"|
        end)

      assert output =~ "live_smoke skip "
      assert output =~ "GOOGLE_MEET_CONFERENCE_RECORD, prepared on 2026-10-30"
      refute output =~ @token

      assert_received {:request, path, query}
      assert path == "/v2/#{@record}"
      assert query == %{"fields" => "name"}
    end

    test "names the first expired variable and asks nothing after it" do
      serve(%{record: "conference_record_unknown", entries: "transcript_entries_not_found"})

      capture_io(fn ->
        reason = LiveMeet.prepared!(@both)[:skip]

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
               assert LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD"]) ==
                        [live_meet_prepared: ["GOOGLE_MEET_CONFERENCE_RECORD"]]
             end) == ""
    end

    test "leaves the test to run on the recorded answers of living data" do
      # A recorded conferenceRecords.get with another field projection stands
      # in for the record probe's 200; only the status counts.
      serve(%{record: "conference_record_get_start_only", entries: "transcript_entries"})

      assert capture_io(fn ->
               assert LiveMeet.prepared!(@both) == [live_meet_prepared: @both]
             end) == ""

      assert_received {:request, _record_path, _record_query}
      assert_received {:request, _entries_path, _entries_query}
    end

    test "leaves the test to run on other errors" do
      # The recorded 400 of the participant list for an ID Google cannot parse.
      serve(%{record: "participants_invalid_record", entries: "participants_invalid_record"})

      assert capture_io(fn ->
               assert LiveMeet.prepared!(@both) == [live_meet_prepared: @both]
             end) == ""

      Req.Test.stub(__MODULE__, &Req.Test.transport_error(&1, :econnrefused))

      assert capture_io(fn ->
               assert LiveMeet.prepared!(@both) == [live_meet_prepared: @both]
             end) == ""
    end
  end

  # Serves recorded responses by request: `:record` for conferenceRecords.get,
  # `:entries` for transcripts.entries.list. The status comes from the body's
  # `error.code` and is 200 without one.
  defp serve(fixtures) do
    test = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test, {:request, conn.request_path, URI.decode_query(conn.query_string)})
      kind = if String.ends_with?(conn.request_path, "/entries"), do: :entries, else: :record
      body = LiveSmoke.fixture!(:google_meet, Map.fetch!(fixtures, kind))

      conn
      |> Plug.Conn.put_status(get_in(body, ["error", "code"]) || 200)
      |> Req.Test.json(body)
    end)
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
