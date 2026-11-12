defmodule Jido.Connect.Tempo.Client.WorkAttributesTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.{Connection, Error}
  alias Jido.Connect.Tempo.{Client, Fixture, WorkAttribute}
  alias Jido.Connect.Tempo.Client.Request

  # Recorded on 2026-11-03 in a work-attribute window with the five test
  # attributes optional: the site's eight attributes on one page, the three
  # outside the test data neutralized to `_Other1_` to `_Other3_` with their
  # recorded type and required flag. The site has fewer than 50 attributes,
  # so pages of three are derived from that page: the same results in
  # Tempo's order, with metadata and a next link for each slice.
  @page "work_attributes_optional"
  @keys [
    "_Other1_",
    "_Other2_",
    "_Other3_",
    "_JclPhase_",
    "_JclBillable_",
    "_JclHours_",
    "_JclAccount_",
    "_JclNote_"
  ]

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

  describe "list_work_attributes/2" do
    test "reads the recorded page at the connection origin and keeps Tempo's order" do
      test_pid = self()

      Req.Test.expect(__MODULE__, fn conn ->
        send(
          test_pid,
          {:request, conn.host, conn.request_path, URI.decode_query(conn.query_string)}
        )

        Fixture.respond(conn, @page)
      end)

      assert {:ok, attributes} = Client.list_work_attributes(request())
      assert Enum.all?(attributes, &match?(%WorkAttribute{}, &1))
      assert Enum.map(attributes, & &1.key) == @keys

      assert_received {:request, "api.us.tempo.io", "/4/work-attributes",
                       %{"offset" => "0", "limit" => "50"}}
    end

    test "returns every attribute across pages, also a required one only on the last page" do
      last_required = fn results ->
        List.update_at(results, -1, &Map.put(&1, "required", true))
      end

      serve_pages(3, results: last_required, report: self())

      assert {:ok, attributes} = Client.list_work_attributes(request(), limit: 3)
      assert Enum.map(attributes, & &1.key) == @keys

      assert [%WorkAttribute{key: "_JclNote_", required: true}] =
               Enum.filter(attributes, & &1.required)

      for offset <- ["0", "3", "6"] do
        assert_received {:page, %{"offset" => ^offset, "limit" => "3"}}
      end
    end

    # Derived: the recorded page without results.
    test "an empty list succeeds" do
      Req.Test.expect(__MODULE__, fn conn ->
        Fixture.respond(conn, @page,
          body: &Map.merge(&1, %{"results" => [], "metadata" => %{&1["metadata"] | "count" => 0}})
        )
      end)

      assert {:ok, []} = Client.list_work_attributes(request())
    end
  end

  describe "a read fails as a whole instead of returning part of the requirements" do
    test "when a later page fails" do
      serve_pages(3, status: %{3 => 500}, pages: 2)

      assert {:error, %Error.ProviderError{reason: :server_error, status: 500}} =
               Client.list_work_attributes(request(), limit: 3)
    end

    test "when a page loops back to an offset already read" do
      serve_pages(3, offset: %{3 => 0}, pages: 2)

      assert {:error, %Error.ProviderError{reason: :repeated_offset}} =
               Client.list_work_attributes(request(), limit: 3)
    end

    test "when a next link leaves the Tempo origins or the path" do
      serve_pages(3,
        next: %{0 => "https://collector.example.com/4/work-attributes?offset=3&limit=3"},
        pages: 1
      )

      assert {:error, %Error.ProviderError{reason: :foreign_next_link}} =
               Client.list_work_attributes(request(), limit: 3)
    end

    test "when a page is malformed" do
      for change <- [
            &Map.delete(&1, "results"),
            &Map.delete(&1, "metadata"),
            &put_in(&1, ["metadata", "count"], 6)
          ] do
        Req.Test.expect(__MODULE__, &Fixture.respond(&1, @page, body: change))

        assert {:error, %Error.ProviderError{reason: :invalid_pagination}} =
                 Client.list_work_attributes(request())
      end
    end

    test "when an attribute on a later page is malformed, with its position and field" do
      serve_pages(3,
        results: fn results -> List.update_at(results, 4, &Map.delete(&1, "required")) end
      )

      assert {:error,
              %Error.ProviderError{
                reason: :invalid_work_attribute,
                delivery: :response_received,
                details: %{index: 4, field: "required"}
              }} = Client.list_work_attributes(request(), limit: 3)
    end

    test "when the page bound is reached before the last page" do
      serve_pages(1, pages: 1)

      assert {:error, %Error.ProviderError{reason: :page_limit_exceeded}} =
               Client.list_work_attributes(request(), limit: 3, max_pages: 1)
    end
  end

  # Serves the recorded results in pages of `size`. Options: `:results`
  # changes the full result list before it is sliced, `:status` maps an
  # offset to an HTTP status, `:next` maps an offset to another next link,
  # `:offset` maps a requested offset to the page served instead, `:pages`
  # is the number of expected requests and `:report` receives
  # `{:page, query}` for each request.
  defp serve_pages(size, opts) do
    results = Keyword.get(opts, :results, & &1).(Fixture.recorded!(@page)["body"]["results"])
    pages = Keyword.get(opts, :pages, div(length(results) + size - 1, size))
    report = Keyword.get(opts, :report)

    Req.Test.expect(__MODULE__, pages, fn conn ->
      query = URI.decode_query(conn.query_string)
      if report, do: send(report, {:page, query})
      requested = String.to_integer(query["offset"])
      offset = Map.get(Keyword.get(opts, :offset, %{}), requested, requested)
      slice = Enum.slice(results, offset, size)
      default_next = if offset + size < length(results), do: link(offset + size, size)
      next = Map.get(Keyword.get(opts, :next, %{}), offset, default_next)
      status = Map.get(Keyword.get(opts, :status, %{}), requested)

      metadata =
        %{"count" => length(slice), "offset" => offset, "limit" => size}
        |> then(&if next, do: Map.put(&1, "next", next), else: &1)

      Fixture.respond(conn, @page,
        status: status || 200,
        body: &%{&1 | "results" => slice, "metadata" => metadata}
      )
    end)
  end

  defp link(offset, size),
    do: "https://api.tempo.io/4/work-attributes?offset=#{offset}&limit=#{size}"

  defp request do
    connection =
      Connection.new!(%{
        id: "tempo_conn_1",
        provider: :tempo,
        profile: :oauth2_user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        subject: %{account_id: "account-1"},
        status: :connected,
        scopes: ["tempo.worklogs.read"],
        metadata: %{api_origin: "https://api.us.tempo.io"}
      })

    {:ok, request} = Request.new(connection, %{access_token: "tempo-oauth-token-273"})
    request
  end
end
