defmodule Jido.Connect.Jira.Client.ExpandedActionsTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.Jira.Client
  alias Jido.Connect.Jira.Client.{Request, Transport}
  alias Jido.Connect.Jira.TestRuntime

  setup {Req.Test, :verify_on_exit!}

  setup do
    previous = Application.get_env(:jido_connect_jira, :jira_req_options)
    Application.put_env(:jido_connect_jira, :jira_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      if previous,
        do: Application.put_env(:jido_connect_jira, :jira_req_options, previous),
        else: Application.delete_env(:jido_connect_jira, :jira_req_options)
    end)

    runtime = TestRuntime.build(provider_client: Client)
    assert {:ok, request} = Request.from_runtime(runtime)
    %{request: request}
  end

  test "uses the Jira Software board endpoints and normalizes paging", %{request: request} do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/rest/agile/1.0/board"

      assert URI.decode_query(conn.query_string) == %{
               "maxResults" => "20",
               "name" => "Docket",
               "projectKeyOrId" => "DOC",
               "startAt" => "5",
               "type" => "kanban"
             }

      Req.Test.json(conn, %{
        startAt: 5,
        maxResults: 20,
        total: 1,
        isLast: true,
        values: [board()]
      })
    end)

    assert {:ok, %{boards: [%{id: "84"}], offset: 5, limit: 20, is_last: true}} =
             Client.list_boards(request,
               name: "Docket",
               project: "DOC",
               type: "kanban",
               offset: 5,
               limit: 20
             )

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/rest/agile/1.0/board/84"
      Req.Test.json(conn, board())
    end)

    assert {:ok, %{id: "84", name: "Docket board"}} = Client.get_board(84, request)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/rest/agile/1.0/board"
      body = json_body(conn)
      assert body.filterId == 10_000
      assert body.location == %{projectKeyOrId: "DOC", type: "project"}
      Req.Test.json(conn, board())
    end)

    assert {:ok, %{id: "84"}} =
             Client.create_board(
               %{
                 name: "Docket board",
                 type: "kanban",
                 filter_id: 10_000,
                 location: "project",
                 project: "DOC"
               },
               request
             )
  end

  test "uses saved-filter endpoints and strict normalized results", %{request: request} do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/rest/api/3/filter/search"
      assert URI.decode_query(conn.query_string)["maxResults"] == "20"

      Req.Test.json(conn, %{
        startAt: 0,
        maxResults: 20,
        total: 1,
        isLast: true,
        values: [filter()]
      })
    end)

    assert {:ok, %{filters: [%{id: "10000"}], total: 1}} =
             Client.list_filters(request, name: "Docket", offset: 0, limit: 20)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/rest/api/3/filter/10000"
      Req.Test.json(conn, filter())
    end)

    assert {:ok, %{id: "10000", query: "project = DOC"}} = Client.get_filter(10_000, request)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/rest/api/3/filter"
      assert json_body(conn).jql == "project = DOC"
      Req.Test.json(conn, filter())
    end)

    assert {:ok, %{id: "10000"}} =
             Client.create_filter(
               %{name: "Docket", query: "project = DOC", favorite: false},
               request
             )

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/rest/api/3/filter/10000"
      assert json_body(conn).name == "Docket"
      Req.Test.json(conn, filter())
    end)

    assert {:ok, %{id: "10000"}} =
             Client.update_filter(10_000, %{name: "Docket", query: "project = DOC"}, request)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/rest/api/3/filter/10000/columns"
      Req.Test.json(conn, columns())
    end)

    assert {:ok, %{filter_id: "10000", columns: [%{value: "issuekey"}]}} =
             Client.get_filter_columns(10_000, request)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/rest/api/3/filter/10000/columns"
      assert json_body(conn) == %{columns: ["issuekey", "summary"]}
      Req.Test.json(conn, %{})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/rest/api/3/filter/10000/columns"
      Req.Test.json(conn, columns())
    end)

    assert {:ok, %{updated: true, filter_id: "10000"}} =
             Client.update_filter_columns(10_000, ["issuekey", "summary"], request)
  end

  test "filter share replacement resolves projects before writes and does not retry", %{
    request: request
  } do
    test_pid = self()

    Req.Test.expect(__MODULE__, fn conn ->
      send(test_pid, {:share_call, conn.method, conn.request_path})
      assert conn.method == "GET"
      Req.Test.json(conn, [%{id: 7, type: "global"}])
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      send(test_pid, {:share_call, conn.method, conn.request_path})
      assert conn.method == "GET"
      Req.Test.json(conn, %{id: "10010", key: "DOC", name: "Docs"})
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      send(test_pid, {:share_call, conn.method, conn.request_path})
      assert conn.method == "DELETE"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      send(test_pid, {:share_call, conn.method, conn.request_path})
      assert conn.method == "POST"
      assert json_body(conn) == %{projectId: "10010", rights: 1, type: "project"}

      Req.Test.json(conn, %{
        id: 8,
        type: "project",
        project: %{id: "10010", key: "DOC", name: "Docs"}
      })
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      send(test_pid, {:share_call, conn.method, conn.request_path})
      assert conn.method == "GET"

      Req.Test.json(conn, [
        %{id: 8, type: "project", project: %{id: "10010", key: "DOC", name: "Docs"}}
      ])
    end)

    assert {:ok, %{updated: true, scope: "projects", permissions: [%{id: "8"}]}} =
             Client.replace_filter_shares(
               10_000,
               %{scope: "projects", projects: ["DOC"]},
               request
             )

    assert_receive {:share_call, "GET", "/rest/api/3/filter/10000/permission"}
    assert_receive {:share_call, "GET", "/rest/api/3/project/DOC"}
    assert_receive {:share_call, "DELETE", "/rest/api/3/filter/10000/permission/7"}
    assert_receive {:share_call, "POST", "/rest/api/3/filter/10000/permission"}
    assert_receive {:share_call, "GET", "/rest/api/3/filter/10000/permission"}
    assert Transport.request(request, req_options: [retry: false]).options.retry == false
  end

  test "filter share transport uncertainty stops without an automatic retry", %{request: request} do
    test_pid = self()

    Req.Test.expect(__MODULE__, fn conn ->
      Req.Test.json(conn, [%{id: 7, type: "global"}])
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      send(test_pid, :delete_attempt)
      Req.Test.transport_error(conn, :timeout)
    end)

    assert {:error,
            %Error.ProviderError{
              delivery: :sent_outcome_unknown,
              mutation?: true,
              provider_idempotency?: false
            } = error} =
             Client.replace_filter_shares(10_000, %{scope: "private"}, request)

    assert Error.retry_guidance(error) == :do_not_retry
    assert_receive :delete_attempt
    refute_receive :delete_attempt, 50
  end

  test "lists transitions and deletes one issue", %{request: request} do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/rest/api/3/issue/PROJ-1/transitions"
      assert URI.decode_query(conn.query_string) == %{"expand" => "transitions.fields"}
      Req.Test.json(conn, %{transitions: [transition()]})
    end)

    assert {:ok, %{issue_key: "PROJ-1", count: 1, transitions: [%{id: "31"}]}} =
             Client.list_issue_transitions("PROJ-1", request)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/rest/api/3/issue/PROJ-1"
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, %{issue_key: "PROJ-1", deleted: true}} =
             Client.delete_issue("PROJ-1", request)
  end

  test "uses Jira Plans endpoints, cursor paging, and JSON Patch", %{request: request} do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/rest/api/3/plans/plan"
      assert URI.decode_query(conn.query_string)["cursor"] == "next-1"

      Req.Test.json(conn, %{
        values: [plan()],
        maxResults: 20,
        total: 1,
        nextPageCursor: "next-2",
        isLast: false
      })
    end)

    assert {:ok, %{plans: [%{id: "1237"}], next_cursor: "next-2", is_last: false}} =
             Client.list_plans(request, cursor: "next-1", limit: 20)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/rest/api/3/plans/plan/1237"
      Req.Test.json(conn, plan())
    end)

    assert {:ok, %{id: "1237", name: "Docket plan"}} = Client.get_plan(1237, request)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/rest/api/3/plans/plan"
      assert json_body(conn).name == "New plan"
      Req.Test.json(conn, 1240)
    end)

    attrs = %{
      name: "New plan",
      issue_sources: [%{type: "Project", value: 10_000}],
      scheduling: %{estimation: "Days"}
    }

    assert {:ok, %{id: "1240", created: true}} = Client.create_plan(attrs, request)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "PUT"
      assert conn.request_path == "/rest/api/3/plans/plan/1237"
      assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json-patch+json"]
      assert json_body(conn) == [%{op: "replace", path: "/name", value: "Renamed"}]
      Plug.Conn.send_resp(conn, 204, "")
    end)

    assert {:ok, %{id: "1237", updated: true, changed_fields: ["name"]}} =
             Client.update_plan(1237, %{name: "Renamed"}, request)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/rest/api/3/plans/plan/1237/duplicate"
      Req.Test.json(conn, 1241)
    end)

    assert {:ok, %{id: "1241", source_plan_id: "1237", duplicated: true}} =
             Client.duplicate_plan(1237, "Copy", request)

    for {operation, expected_path} <- [
          {:archive_plan, "/rest/api/3/plans/plan/1237/archive"},
          {:trash_plan, "/rest/api/3/plans/plan/1237/trash"}
        ] do
      Req.Test.expect(__MODULE__, fn conn ->
        assert conn.method == "PUT"
        assert conn.request_path == expected_path
        Plug.Conn.send_resp(conn, 204, "")
      end)

      assert {:ok, %{id: "1237", updated: true}} = apply(Client, operation, [1237, request])
    end
  end

  test "normalizes provider and malformed-success failures", %{request: request} do
    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(403)
      |> Req.Test.json(%{message: "denied"})
    end)

    assert {:error, %Error.ProviderError{provider: :jira, status: 403}} =
             Client.get_board(84, request)

    Req.Test.expect(__MODULE__, fn conn -> Req.Test.json(conn, %{values: "bad"}) end)

    assert {:error, %Error.ProviderError{provider: :jira, reason: :invalid_response}} =
             Client.list_boards(request)

    Req.Test.expect(__MODULE__, fn conn -> Req.Test.json(conn, %{id: "bad"}) end)

    assert {:error,
            %Error.ProviderError{
              provider: :jira,
              reason: :invalid_response,
              delivery: :response_received,
              mutation?: true,
              provider_idempotency?: false
            } = error} =
             Client.create_board(
               %{name: "Docket", type: "kanban", filter_id: 10_000, location: "user"},
               request
             )

    assert Error.retry_guidance(error) == :do_not_retry
  end

  defp board do
    %{
      id: 84,
      name: "Docket board",
      type: "kanban",
      self: "https://example.atlassian.net/rest/agile/1.0/board/84"
    }
  end

  defp filter do
    %{
      id: "10000",
      name: "Docket",
      jql: "project = DOC",
      description: "Docs",
      favourite: false,
      owner: %{accountId: "user-1", displayName: "User"},
      sharePermissions: [],
      viewUrl: "https://example.atlassian.net/issues/?filter=10000"
    }
  end

  defp columns, do: [%{label: "Key", value: "issuekey"}]

  defp transition do
    %{id: "31", name: "Done", to: %{id: "6", name: "Closed"}, fields: %{}}
  end

  defp plan do
    %{
      id: 1237,
      name: "Docket plan",
      status: "Active",
      issueSources: [%{type: "Project", value: 10_000}],
      scheduling: %{estimation: "Days"}
    }
  end

  defp json_body(conn) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(body, keys: :atoms)
  end
end
