defmodule Jido.Connect.Tempo.Client.WorklogsTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.{Connection, Error}
  alias Jido.Connect.Tempo.{Client, Fixture, Worklog}
  alias Jido.Connect.Tempo.Client.Request

  # Recorded by the live test "lists the own worklogs of the three seeded
  # periods through the action": the test user's 60 worklogs from August 1
  # to October 31, 2026, 50 with a `next` link on `worklogs_own`, 10 without
  # one on `worklogs_own.2`. The last one, 79166, is booked at 00:30 on
  # October 31 in Europe/Berlin and has a description of 778 bytes. The
  # sanitizer replaced the test user's account ID with `account-1`.
  # `worklogs_own_small_page` holds the five worklogs of October 1 in pages
  # of two, `worklogs_own_day` the one of October 31, `worklogs_own_empty.2`
  # the empty answer for July, read after October 30 on `worklogs_own_empty`,
  # and `worklogs_own_jira` the three of October 28, two of them created in
  # Jira, without a comment (79167) and with an empty one (79168).
  @account "account-1"
  @path "/4/worklogs/user/account-1"
  @periods [from: "2026-08-01", to: "2026-10-31"]
  @pages ["worklogs_own", "worklogs_own.2"]

  setup {Req.Test, :verify_on_exit!}

  setup do
    previous = Application.fetch_env(:jido_connect_tempo, :tempo_req_options)
    Application.put_env(:jido_connect_tempo, :tempo_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:jido_connect_tempo, :tempo_req_options, value)
        :error -> Application.delete_env(:jido_connect_tempo, :tempo_req_options)
      end
    end)
  end

  describe "list_own_worklogs/2" do
    test "reads every page of the inclusive range for the connection's account" do
      test_pid = self()

      Req.Test.expect(__MODULE__, 2, fn conn ->
        query = URI.decode_query(conn.query_string)
        send(test_pid, {:page, conn.host, conn.request_path, query})

        case query["offset"] do
          "0" -> Fixture.respond(conn, "worklogs_own")
          "50" -> Fixture.respond(conn, "worklogs_own.2")
        end
      end)

      # The first page announces the second; the final one has no next link.
      assert %{"next" => _next} = Fixture.recorded!("worklogs_own")["body"]["metadata"]
      refute Map.has_key?(Fixture.recorded!("worklogs_own.2")["body"]["metadata"], "next")

      assert {:ok, worklogs} = Client.list_own_worklogs(request(), @periods)
      assert length(worklogs) == 60
      assert Enum.all?(worklogs, &match?(%Worklog{author_account_id: @account}, &1))
      assert Enum.map(worklogs, & &1.tempo_worklog_id) == recorded_ids(@pages)

      assert ["2026-08-01", "2026-08-31", "2026-09-01", "2026-09-30" | _rest] =
               worklogs |> Enum.map(& &1.start_date) |> Enum.uniq()

      assert List.last(worklogs).start_date == "2026-10-31"

      for offset <- ["0", "50"] do
        assert_received {:page, "api.us.tempo.io", @path, query}

        assert query == %{
                 "from" => "2026-08-01",
                 "to" => "2026-10-31",
                 "offset" => offset,
                 "limit" => "50"
               }
      end
    end

    test "keeps every field of a recorded worklog" do
      expect_pages(@pages)

      assert {:ok, worklogs} = Client.list_own_worklogs(request(), @periods)

      assert List.last(worklogs) == %Worklog{
               tempo_worklog_id: 79_166,
               author_account_id: @account,
               start_date: "2026-10-31",
               time_spent_seconds: 1801,
               issue_id: 46_097,
               description: recorded("worklogs_own.2", 79_166)["description"],
               work_attributes: [],
               start_time: "00:30:00",
               start_date_time_utc: "2026-10-30T23:30:00Z",
               billable_seconds: 1801,
               created_at: "2026-11-02T15:40:29Z",
               updated_at: "2026-11-02T15:40:29Z",
               self: "https://api.tempo.io/4/worklogs/79166"
             }
    end

    test "keeps the recorded shapes apart" do
      expect_pages(@pages)

      assert {:ok, worklogs} = Client.list_own_worklogs(request(), @periods)
      by_id = Map.new(worklogs, &{&1.tempo_worklog_id, &1})

      # The booking day is the worker's day, not the UTC date of the start.
      assert %{start_date: "2026-10-31", start_date_time_utc: "2026-10-30T23:30:00Z"} =
               by_id[79_166]

      # A description of 778 bytes, 730 characters, comes back whole.
      assert byte_size(by_id[79_166].description) == 778
      assert String.length(by_id[79_166].description) == 730

      # Exact seconds, none of them whole hours.
      assert {5400, 600, 1801} ==
               {by_id[79_093].time_spent_seconds, by_id[79_099].time_spent_seconds,
                by_id[79_166].time_spent_seconds}

      assert %{billable_seconds: 0, time_spent_seconds: 900} = by_id[79_101]

      # Created through Tempo without a description and with an empty one:
      # Tempo answers both with its default text, so they differ only in IDs
      # and times.
      volatile = [:tempo_worklog_id, :self, :created_at, :updated_at]
      assert Map.drop(by_id[79_099], volatile) == Map.drop(by_id[79_100], volatile)
      assert by_id[79_099].description == "Working on work item JCL-2"
      assert by_id[79_099].tempo_worklog_id != by_id[79_100].tempo_worklog_id
    end

    test "reads small pages until the final page" do
      test_pid = self()

      expect_pages(
        ["worklogs_own_small_page", "worklogs_own_small_page.2", "worklogs_own_small_page.3"],
        page_size: 2,
        report: test_pid
      )

      assert {:ok, worklogs} =
               Client.list_own_worklogs(request(),
                 from: "2026-10-01",
                 to: "2026-10-01",
                 limit: 2
               )

      assert Enum.map(worklogs, & &1.tempo_worklog_id) == [79_097, 79_099, 79_100, 79_101, 79_131]

      for offset <- ["0", "2", "4"] do
        assert_received {:page, %{"offset" => ^offset, "limit" => "2"}}
      end
    end

    test "an empty range returns no worklogs" do
      Req.Test.expect(__MODULE__, &Fixture.respond(&1, "worklogs_own_empty.2"))

      assert {:ok, []} = Client.list_own_worklogs(request(), from: "2026-07-01", to: "2026-07-31")
    end

    test "sends the account ID as one encoded path segment" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.request_path == "/4/worklogs/user/557058%3Af0e1%2Fa%20b"
        Fixture.respond(conn, "worklogs_own_empty.2")
      end)

      assert {:ok, []} =
               Client.list_own_worklogs(request("557058:f0e1/a b"),
                 from: "2026-07-01",
                 to: "2026-07-31"
               )
    end
  end

  describe "a read fails as a whole" do
    test "when a later page fails" do
      Req.Test.expect(__MODULE__, 2, fn conn ->
        case URI.decode_query(conn.query_string)["offset"] do
          "0" -> Fixture.respond(conn, "worklogs_own")
          "50" -> Fixture.respond(conn, "worklogs_own.2", status: 503)
        end
      end)

      assert {:error, %Error.ProviderError{reason: :server_error, status: 503}} =
               Client.list_own_worklogs(request(), @periods)
    end

    test "when a later page is malformed" do
      Req.Test.expect(__MODULE__, 2, fn conn ->
        case URI.decode_query(conn.query_string)["offset"] do
          "0" -> Fixture.respond(conn, "worklogs_own")
          "50" -> Fixture.respond(conn, "worklogs_own.2", body: &Map.delete(&1, "metadata"))
        end
      end)

      assert {:error, %Error.ProviderError{reason: :invalid_pagination}} =
               Client.list_own_worklogs(request(), @periods)
    end

    test "when a worklog of another account is on a later page" do
      expect_pages(@pages, last: &put_in(&1, ["author", "accountId"], "account-2"))

      assert {:error,
              %Error.ProviderError{
                reason: :foreign_worklog_author,
                details: %{tempo_worklog_id: 79_166} = details
              }} = Client.list_own_worklogs(request(), @periods)

      refute inspect(details) =~ "account-2"
    end

    test "when a booking day lies outside the range" do
      for day <- ["2026-07-31", "2026-11-01"] do
        expect_pages(@pages, last: &Map.put(&1, "startDate", day))

        assert {:error,
                %Error.ProviderError{
                  reason: :worklog_outside_range,
                  details: %{tempo_worklog_id: 79_166, start_date: ^day}
                }} = Client.list_own_worklogs(request(), @periods)
      end
    end
  end

  describe "normalization" do
    # The last recorded worklog with one field removed or broken.
    test "a worklog without Tempo ID, author, booking date, duration or issue ID fails the read" do
      for {change, field} <- [
            {&Map.delete(&1, "tempoWorklogId"), "tempoWorklogId"},
            {&Map.put(&1, "tempoWorklogId", "79166"), "tempoWorklogId"},
            {&Map.put(&1, "tempoWorklogId", 0), "tempoWorklogId"},
            {&Map.delete(&1, "author"), "author.accountId"},
            {&put_in(&1, ["author", "accountId"], ""), "author.accountId"},
            {&Map.put(&1, "author", "account-1"), "author.accountId"},
            {&Map.delete(&1, "startDate"), "startDate"},
            {&Map.put(&1, "startDate", "2026-10-32"), "startDate"},
            {&Map.delete(&1, "timeSpentSeconds"), "timeSpentSeconds"},
            {&Map.put(&1, "timeSpentSeconds", 1801.5), "timeSpentSeconds"},
            {&Map.put(&1, "timeSpentSeconds", "1801"), "timeSpentSeconds"},
            {&Map.put(&1, "timeSpentSeconds", -1), "timeSpentSeconds"},
            {&Map.delete(&1, "issue"), "issue.id"},
            {&put_in(&1, ["issue", "id"], "46097"), "issue.id"},
            {&put_in(&1, ["issue", "id"], 0), "issue.id"},
            {fn _worklog -> "79166" end, "worklog"}
          ] do
        expect_pages(@pages, last: change)

        assert {:error,
                %Error.ProviderError{
                  reason: :invalid_worklog,
                  details: %{field: ^field}
                } = error} = Client.list_own_worklogs(request(), @periods)

        refute inspect(error) =~ "JCL live"
      end
    end

    test "an optional field of the wrong type fails the read" do
      for {change, field} <- [
            {&Map.put(&1, "description", 5), "description"},
            {&Map.put(&1, "billableSeconds", -1), "billableSeconds"},
            {&Map.put(&1, "startTime", "25:00:00"), "startTime"},
            {&Map.put(&1, "startDateTimeUtc", "yesterday"), "startDateTimeUtc"},
            {&Map.put(&1, "createdAt", "yesterday"), "createdAt"},
            {&put_in(&1, ["attributes", "values"], [%{"value" => "x"}]), "attributes.values"},
            {&put_in(&1, ["attributes", "values"], [%{"key" => "", "value" => "x"}]),
             "attributes.values"},
            {&put_in(&1, ["attributes", "values"], [%{"key" => "_JclHours_", "value" => 5}]),
             "attributes.values"},
            {&put_in(&1, ["attributes", "values"], %{}), "attributes.values"}
          ] do
        expect_pages(@pages, last: change)

        assert {:error, %Error.ProviderError{reason: :invalid_worklog, details: %{field: ^field}}} =
                 Client.list_own_worklogs(request(), @periods)
      end
    end

    test "an empty description stays empty" do
      Req.Test.expect(__MODULE__, &Fixture.respond(&1, "worklogs_own_jira"))

      assert {:ok,
              [
                %Worklog{
                  tempo_worklog_id: 79_128,
                  description: "JCL live seed worklog: filler 27"
                },
                %Worklog{tempo_worklog_id: 79_167, description: ""},
                %Worklog{tempo_worklog_id: 79_168, description: ""}
              ]} = Client.list_own_worklogs(request(), from: "2026-10-28", to: "2026-10-28")
    end

    # No recording leaves the description out: Tempo answers a worklog
    # created through Tempo without one with its default text, and one
    # created in Jira without a comment with "". So the absent case is the
    # recorded worklog without that field.
    test "an absent description stays nil" do
      Req.Test.expect(__MODULE__, fn conn ->
        Fixture.respond(conn, "worklogs_own_jira",
          body: &update_result(&1, 1, fn worklog -> Map.delete(worklog, "description") end)
        )
      end)

      assert {:ok, [_seed, %Worklog{tempo_worklog_id: 79_167, description: nil}, _empty]} =
               Client.list_own_worklogs(request(), from: "2026-10-28", to: "2026-10-28")
    end

    test "optional fields that Tempo leaves out stay nil" do
      optional =
        ~w(startTime startDateTimeUtc billableSeconds createdAt updatedAt self attributes)

      expect_pages(@pages, last: &Map.drop(&1, optional))

      assert {:ok, worklogs} = Client.list_own_worklogs(request(), @periods)

      assert %Worklog{
               tempo_worklog_id: 79_166,
               work_attributes: [],
               start_time: nil,
               start_date_time_utc: nil,
               billable_seconds: nil,
               created_at: nil,
               updated_at: nil,
               self: nil
             } = List.last(worklogs)
    end

    # Recorded in a work-attribute window on 2026-11-03: the seeded worklog
    # 79097 of October 1 with a value for each test attribute, in Tempo's
    # order, the first one a stored value of the static list `_JclPhase_`.
    # The value without a string is derived from it.
    test "work attribute values keep their key and value" do
      Req.Test.expect(__MODULE__, &Fixture.respond(&1, "work_attribute_values"))

      assert {:ok, [worklog | others]} =
               Client.list_own_worklogs(request(), from: "2026-10-01", to: "2026-10-01")

      assert worklog.tempo_worklog_id == 79_097

      assert worklog.work_attributes == [
               %{key: "_JclPhase_", value: "0be722c9-c4de-452b-a6bd-0a59e1b03c80"},
               %{key: "_JclNote_", value: "JCL live note"},
               %{key: "_JclHours_", value: "1.5"},
               %{key: "_JclBillable_", value: "true"},
               %{key: "_JclAccount_", value: "JCL-PROJECT"}
             ]

      assert Enum.all?(others, &(&1.work_attributes == []))

      Req.Test.expect(__MODULE__, fn conn ->
        Fixture.respond(conn, "work_attribute_values",
          body: fn body ->
            update_in(body, ["results"], fn [first | rest] ->
              [update_in(first, ["attributes", "values"], &[Map.delete(hd(&1), "value")]) | rest]
            end)
          end
        )
      end)

      assert {:ok, [%{work_attributes: [%{key: "_JclPhase_", value: nil}]} | _others]} =
               Client.list_own_worklogs(request(), from: "2026-10-01", to: "2026-10-01")
    end
  end

  describe "the range" do
    test "an invalid or reversed range fails before any request" do
      test_pid = self()

      Req.Test.stub(__MODULE__, fn conn ->
        send(test_pid, :requested)
        Fixture.respond(conn, "worklogs_own")
      end)

      for {opts, field} <- [
            {[from: "2026-10-32", to: "2026-10-31"], :from},
            {[from: "2026/10/01", to: "2026-10-31"], :from},
            {[from: "+2026-10-01", to: "2026-10-31"], :from},
            {[from: "20261001", to: "2026-10-31"], :from},
            {[from: ~D[2026-10-01], to: "2026-10-31"], :from},
            {[to: "2026-10-31"], :from},
            {[from: "2026-10-01", to: ""], :to},
            {[from: "2026-10-01"], :to},
            {[from: "2026-10-02", to: "2026-10-01"], :to}
          ] do
        assert {:error,
                %Error.ValidationError{
                  reason: :invalid_date_range,
                  subject: ^field,
                  details: %{field: ^field}
                }} = Client.list_own_worklogs(request(), opts)
      end

      refute_received :requested
    end

    test "a one-day range sends the same day as from and to" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert %{"from" => "2026-10-31", "to" => "2026-10-31"} =
                 URI.decode_query(conn.query_string)

        Fixture.respond(conn, "worklogs_own_day")
      end)

      assert {:ok, [%Worklog{tempo_worklog_id: 79_166}]} =
               Client.list_own_worklogs(request(), from: "2026-10-31", to: "2026-10-31")
    end

    test "never sends updatedFrom or other query parameters of the caller" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.query_string |> URI.decode_query() |> Map.keys() |> Enum.sort() ==
                 ["from", "limit", "offset", "to"]

        Fixture.respond(conn, "worklogs_own_empty.2")
      end)

      assert {:ok, []} =
               Client.list_own_worklogs(request(),
                 from: "2026-07-01",
                 to: "2026-07-31",
                 params: [updatedFrom: "2026-10-30"],
                 updatedFrom: "2026-10-30"
               )
    end

    test "passes the page size and the read bounds to the pagination" do
      Req.Test.expect(__MODULE__, fn conn ->
        assert URI.decode_query(conn.query_string)["limit"] == "2"
        Fixture.respond(conn, "worklogs_own_small_page")
      end)

      assert {:error, %Error.ProviderError{reason: :result_limit_exceeded}} =
               Client.list_own_worklogs(request(),
                 from: "2026-10-01",
                 to: "2026-10-01",
                 limit: 2,
                 max_results: 1
               )
    end

    test "a page bound stops the read before the next page" do
      Req.Test.expect(__MODULE__, &Fixture.respond(&1, "worklogs_own_small_page"))

      assert {:error,
              %Error.ProviderError{reason: :page_limit_exceeded, details: %{max_pages: 1}}} =
               Client.list_own_worklogs(request(),
                 from: "2026-10-01",
                 to: "2026-10-01",
                 limit: 2,
                 max_pages: 1
               )
    end
  end

  # Answers each page request with the recorded page for its offset.
  # Options: `:page_size` (50), `:first` changes the first worklog of the
  # first page, `:last` the last worklog of the last page, and `:report`
  # receives `{:page, query}` for each request.
  defp expect_pages(names, opts \\ []) do
    first = Keyword.get(opts, :first, & &1)
    last = Keyword.get(opts, :last, & &1)
    page_size = Keyword.get(opts, :page_size, 50)
    report = Keyword.get(opts, :report)
    pages = length(names)

    Req.Test.expect(__MODULE__, pages, fn conn ->
      query = URI.decode_query(conn.query_string)
      if report, do: send(report, {:page, query})
      index = div(String.to_integer(query["offset"]), page_size)

      change = fn body ->
        body
        |> then(&if(index == 0, do: update_result(&1, 0, first), else: &1))
        |> then(&if(index == pages - 1, do: update_result(&1, -1, last), else: &1))
      end

      Fixture.respond(conn, Enum.at(names, index), body: change)
    end)
  end

  defp update_result(body, position, fun),
    do: update_in(body, ["results"], &List.update_at(&1, position, fun))

  defp recorded_ids(names) do
    for name <- names,
        result <- Fixture.recorded!(name)["body"]["results"],
        do: result["tempoWorklogId"]
  end

  defp recorded(name, id) do
    Enum.find(Fixture.recorded!(name)["body"]["results"], &(&1["tempoWorklogId"] == id))
  end

  defp request(account_id \\ @account) do
    connection =
      Connection.new!(%{
        id: "tempo_conn_1",
        provider: :tempo,
        profile: :api_token,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        subject: %{account_id: account_id},
        status: :connected,
        scopes: ["tempo.worklogs.read"],
        metadata: %{api_origin: "https://api.us.tempo.io"}
      })

    {:ok, request} = Request.new(connection, %{api_token: "tempo-api-token-272"})
    request
  end
end
