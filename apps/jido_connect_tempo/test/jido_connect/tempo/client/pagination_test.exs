defmodule Jido.Connect.Tempo.Client.PaginationTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.{Connection, Error}
  alias Jido.Connect.Tempo.Client.{Pagination, Request}
  alias Jido.Connect.Tempo.Fixture

  # The recorded October read of the test user: 50 worklogs with a `next`
  # link on the first page, 5 without one on the second. The sanitizer
  # replaced the account ID with `account-1`, also in the `next` links.
  @path "/4/worklogs/user/account-1"
  @october [params: [from: "2026-10-01", to: "2026-10-31"]]

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

  test "the recorded next link names the global origin, not the regional one" do
    assert "https://api.tempo.io" <> @path <> "?" <> _query =
             Fixture.recorded!("worklogs_page")["body"]["metadata"]["next"]
  end

  test "reads every page, rebuilding each request at the connection origin" do
    test_pid = self()

    Req.Test.expect(__MODULE__, 2, fn conn ->
      query = URI.decode_query(conn.query_string)
      send(test_pid, {:page, conn.host, conn.request_path, query})

      case query["offset"] do
        "0" -> Fixture.respond(conn, "worklogs_page")
        "50" -> Fixture.respond(conn, "worklogs_page.2")
      end
    end)

    assert {:ok, worklogs} = Pagination.collect(request(), @path, @october)
    assert ids(worklogs) == ids(page_results("worklogs_page") ++ page_results("worklogs_page.2"))
    assert length(worklogs) == 55

    for offset <- ["0", "50"] do
      assert_received {:page, "api.us.tempo.io", @path,
                       %{"from" => "2026-10-01", "to" => "2026-10-31", "offset" => ^offset} =
                         query}

      assert query["limit"] == "50"
    end
  end

  test "a path without a leading slash reads every page" do
    Req.Test.expect(__MODULE__, 2, fn conn ->
      assert conn.request_path == @path

      case URI.decode_query(conn.query_string)["offset"] do
        "0" -> Fixture.respond(conn, "worklogs_page")
        "50" -> Fixture.respond(conn, "worklogs_page.2")
      end
    end)

    "/" <> relative = @path
    assert {:ok, worklogs} = Pagination.collect(request(), relative, @october)
    assert length(worklogs) == 55
  end

  # The first recorded page with its `next` link moved to another origin,
  # another scheme or another path.
  test "a next link outside the Tempo origins or the requested path fails without a request" do
    for next <- [
          "https://collector.example.com/4/worklogs/user/account-1?offset=50&limit=50",
          "http://api.tempo.io/4/worklogs/user/account-1?offset=50&limit=50",
          "https://api.tempo.io:8443/4/worklogs/user/account-1?offset=50&limit=50",
          "https://api.tempo.io/4/worklogs/user/account-2?offset=50&limit=50",
          "/4/worklogs/user/account-1?offset=50&limit=50"
        ] do
      Req.Test.expect(__MODULE__, fn conn ->
        Fixture.respond(conn, "worklogs_page", body: &put_in(&1, ["metadata", "next"], next))
      end)

      assert {:error, %Error.ProviderError{provider: :tempo, reason: :foreign_next_link}} =
               Pagination.collect(request(), @path, @october)
    end
  end

  # The first recorded page with a `next` link that disagrees with the
  # metadata: a short page of 45 announcing offset 50, a link that skips to
  # offset 60, and a link without an offset.
  test "a next link whose offset is not the page offset plus count fails without a request" do
    for change <- [
          fn body ->
            body
            |> update_in(["results"], &Enum.take(&1, 45))
            |> put_in(["metadata", "count"], 45)
          end,
          &update_in(&1, ["metadata", "next"], fn next ->
            String.replace(next, "offset=50", "offset=60")
          end),
          &update_in(&1, ["metadata", "next"], fn next ->
            String.replace(next, "offset=50&", "")
          end)
        ] do
      Req.Test.expect(__MODULE__, &Fixture.respond(&1, "worklogs_page", body: change))

      assert {:error, %Error.ProviderError{reason: :invalid_pagination}} =
               Pagination.collect(request(), @path, @october)
    end
  end

  # The second request gets the first recorded page again, as a server stuck
  # on one offset would send it.
  test "a repeated offset fails the whole read" do
    Req.Test.expect(__MODULE__, 2, &Fixture.respond(&1, "worklogs_page"))

    assert {:error, %Error.ProviderError{reason: :repeated_offset, details: %{offset: 0}}} =
             Pagination.collect(request(), @path, @october)
  end

  # The first recorded page without results but with its `next` link.
  test "an empty page that announces a next page fails as a repeated offset" do
    Req.Test.expect(__MODULE__, fn conn ->
      Fixture.respond(conn, "worklogs_page",
        body: fn body ->
          body |> put_in(["results"], []) |> put_in(["metadata", "count"], 0)
        end
      )
    end)

    assert {:error, %Error.ProviderError{reason: :repeated_offset}} =
             Pagination.collect(request(), @path, @october)
  end

  test "a result count at the limit succeeds and one over it fails the whole read" do
    Req.Test.stub(__MODULE__, fn conn ->
      case URI.decode_query(conn.query_string)["offset"] do
        "0" -> Fixture.respond(conn, "worklogs_page")
        "50" -> Fixture.respond(conn, "worklogs_page.2")
      end
    end)

    assert {:ok, worklogs} = Pagination.collect(request(), @path, @october ++ [max_results: 55])
    assert length(worklogs) == 55

    assert {:error,
            %Error.ProviderError{
              reason: :result_limit_exceeded,
              details: %{max_results: 54}
            }} = Pagination.collect(request(), @path, @october ++ [max_results: 54])
  end

  test "a page count at the limit succeeds and one over it fails before the next request" do
    Req.Test.expect(__MODULE__, 3, fn conn ->
      case URI.decode_query(conn.query_string)["offset"] do
        "0" -> Fixture.respond(conn, "worklogs_page")
        "50" -> Fixture.respond(conn, "worklogs_page.2")
      end
    end)

    assert {:ok, _worklogs} = Pagination.collect(request(), @path, @october ++ [max_pages: 2])

    assert {:error, %Error.ProviderError{reason: :page_limit_exceeded, details: %{max_pages: 1}}} =
             Pagination.collect(request(), @path, @october ++ [max_pages: 1])
  end

  # The first recorded page with its metadata changed.
  test "a malformed page fails the whole read" do
    for change <- [
          &Map.delete(&1, "results"),
          &Map.delete(&1, "metadata"),
          &put_in(&1, ["metadata", "count"], 49),
          &put_in(&1, ["metadata", "offset"], 10),
          &put_in(&1, ["metadata", "next"], 42)
        ] do
      Req.Test.expect(__MODULE__, &Fixture.respond(&1, "worklogs_page", body: change))

      assert {:error, %Error.ProviderError{reason: :invalid_pagination}} =
               Pagination.collect(request(), @path, @october)
    end
  end

  # The second page fails with the recorded 400 body replayed as 503.
  test "a failed page fails the whole read" do
    Req.Test.expect(__MODULE__, 2, fn conn ->
      case URI.decode_query(conn.query_string)["offset"] do
        "0" -> Fixture.respond(conn, "worklogs_page")
        "50" -> Fixture.respond(conn, "bad_request", status: 503)
      end
    end)

    assert {:error, %Error.ProviderError{reason: :server_error, status: 503}} =
             Pagination.collect(request(), @path, @october)
  end

  test "documents its defaults" do
    assert Pagination.defaults() == [limit: 50, max_pages: 20, max_results: 1_000]
  end

  test "an invalid bound or params value is a validation error before any request" do
    for {option, value} <- [
          limit: 0,
          max_pages: -1,
          max_results: "10",
          params: "from=2026-10-01",
          params: [~c"from"]
        ] do
      assert {:error,
              %Error.ValidationError{reason: :invalid_pagination_option, subject: ^option}} =
               Pagination.collect(request(), @path, [{option, value}])
    end
  end

  # The first recorded page without its `next` link ends the read.
  test "sends :limit as the page size and drops the caller's offset and limit" do
    test_pid = self()

    for params <- [
          [from: "2026-10-01", to: "2026-10-31", offset: 99, limit: 7],
          %{"from" => "2026-10-01", "to" => "2026-10-31", "offset" => 99, "limit" => 7}
        ] do
      Req.Test.expect(__MODULE__, fn conn ->
        send(test_pid, {:query, Enum.to_list(URI.query_decoder(conn.query_string))})

        Fixture.respond(conn, "worklogs_page",
          body: &update_in(&1, ["metadata"], fn metadata -> Map.delete(metadata, "next") end)
        )
      end)

      assert {:ok, _worklogs} = Pagination.collect(request(), @path, params: params, limit: 25)
      assert_received {:query, query}

      assert Enum.sort(query) == [
               {"from", "2026-10-01"},
               {"limit", "25"},
               {"offset", "0"},
               {"to", "2026-10-31"}
             ]
    end
  end

  defp page_results(name), do: Fixture.recorded!(name)["body"]["results"]
  defp ids(worklogs), do: Enum.map(worklogs, & &1["tempoWorklogId"])

  defp request do
    connection =
      Connection.new!(%{
        id: "tempo_conn_1",
        provider: :tempo,
        profile: :api_token,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        subject: %{account_id: "account-1"},
        status: :connected,
        metadata: %{api_origin: "https://api.us.tempo.io"}
      })

    {:ok, request} = Request.new(connection, %{api_token: "tok"})
    request
  end
end
