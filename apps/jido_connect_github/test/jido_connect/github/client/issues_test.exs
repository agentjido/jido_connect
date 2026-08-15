defmodule Jido.Connect.GitHub.Client.IssuesTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.GitHub.Client

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:jido_connect_github, :github_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_github, :github_req_options)
    end)
  end

  test "list issues sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/org/repo/issues"

      assert %{
               "direction" => "desc",
               "per_page" => "100",
               "sort" => "created",
               "state" => "open"
             } = URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, [
        %{number: 1, html_url: "https://github.test/1", title: "Issue", state: "open"}
      ])
    end)

    assert {:ok, [%{number: 1, url: "https://github.test/1"}]} =
             Client.list_issues("org/repo", "open", "token")
  end

  test "create issue sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/org/repo/issues"

      Req.Test.json(conn, %{
        number: 2,
        html_url: "https://github.test/2",
        title: "Bug",
        state: "open"
      })
    end)

    assert {:ok, %{number: 2, title: "Bug"}} =
             Client.create_issue("org/repo", %{title: "Bug"}, "token")
  end

  test "update issue sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/repos/org/repo/issues/2"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{
               "assignees" => ["octocat"],
               "labels" => ["bug"],
               "milestone" => 3,
               "state" => "open",
               "title" => "Bug"
             } = Jason.decode!(body)

      Req.Test.json(conn, %{
        number: 2,
        html_url: "https://github.test/2",
        title: "Bug",
        state: "open"
      })
    end)

    assert {:ok, %{number: 2, title: "Bug"}} =
             Client.update_issue(
               "org/repo",
               2,
               %{
                 title: "Bug",
                 state: "open",
                 labels: ["bug"],
                 milestone: 3,
                 assignees: ["octocat"]
               },
               "token"
             )
  end

  test "add issue labels sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/org/repo/issues/2/labels"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert %{"labels" => ["bug", "triage"]} = Jason.decode!(body)
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, [
        %{
          name: "bug",
          color: "d73a4a",
          description: "Something is not working"
        },
        %{
          name: "triage",
          color: "ededed",
          description: nil
        }
      ])
    end)

    assert {:ok,
            [
              %{name: "bug", color: "d73a4a", description: "Something is not working"},
              %{name: "triage", color: "ededed"}
            ]} = Client.add_issue_labels("org/repo", 2, ["bug", "triage"], "token")
  end

  test "remove issue label sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/repos/org/repo/issues/2/labels/bug"
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, [%{name: "triage", color: "ededed", description: nil}])
    end)

    assert {:ok, [%{name: "triage", color: "ededed"}]} =
             Client.remove_issue_label("org/repo", 2, "bug", "token")
  end

  test "remove issue label percent-encodes the label name" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "DELETE"
      assert conn.request_path == "/repos/org/repo/issues/2/labels/good%20first%20issue"

      Req.Test.json(conn, [])
    end)

    assert {:ok, []} =
             Client.remove_issue_label("org/repo", 2, "good first issue", "token")
  end

  test "assign issue sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/org/repo/issues/2/assignees"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert %{"assignees" => ["octocat", "mona"]} = Jason.decode!(body)
      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, %{
        number: 2,
        html_url: "https://github.test/2",
        title: "Bug",
        state: "open",
        assignees: [
          %{login: "octocat", id: 1, type: "User", html_url: "https://github.test/octocat"},
          %{login: "mona", id: 2, type: "User", html_url: "https://github.test/mona"}
        ]
      })
    end)

    assert {:ok,
            %{
              number: 2,
              title: "Bug",
              state: "open",
              assignees: [
                %{login: "octocat", id: 1, type: "User", url: "https://github.test/octocat"},
                %{login: "mona", id: 2, type: "User", url: "https://github.test/mona"}
              ]
            }} = Client.assign_issue("org/repo", 2, ["octocat", "mona"], "token")
  end

  test "create issue comment sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/repos/org/repo/issues/2/comments"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert %{"body" => "Ship it"} = Jason.decode!(body)

      Req.Test.json(conn, %{
        id: 3,
        html_url: "https://github.test/comments/3",
        body: "Ship it"
      })
    end)

    assert {:ok, %{id: 3, body: "Ship it"}} =
             Client.create_issue_comment("org/repo", 2, "Ship it", "token")
  end

  test "list issue comments sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == "/repos/org/repo/issues/2/comments"

      assert %{
               "page" => "2",
               "per_page" => "10",
               "since" => "2026-04-29T10:00:00Z"
             } = URI.decode_query(conn.query_string)

      assert ["Bearer token"] = Plug.Conn.get_req_header(conn, "authorization")

      Req.Test.json(conn, [
        %{
          id: 3,
          html_url: "https://github.test/comments/3",
          body: "Ship it",
          user: %{login: "octocat", id: 1, type: "User"},
          author_association: "MEMBER",
          created_at: "2026-04-29T10:01:00Z",
          updated_at: "2026-04-29T10:02:00Z"
        }
      ])
    end)

    assert {:ok,
            [
              %{
                id: 3,
                url: "https://github.test/comments/3",
                body: "Ship it",
                user: %{login: "octocat"},
                author_association: "MEMBER",
                created_at: "2026-04-29T10:01:00Z",
                updated_at: "2026-04-29T10:02:00Z"
              }
            ]} =
             Client.list_issue_comments(
               %{
                 repo: "org/repo",
                 issue_number: 2,
                 since: "2026-04-29T10:00:00Z",
                 page: 2,
                 per_page: 10
               },
               "token"
             )
  end

  test "close issue sends expected request" do
    Req.Test.stub(__MODULE__, fn conn ->
      assert conn.method == "PATCH"
      assert conn.request_path == "/repos/org/repo/issues/2"

      {:ok, body, conn} = Plug.Conn.read_body(conn)

      assert %{"state" => "closed", "state_reason" => "completed"} = Jason.decode!(body)

      Req.Test.json(conn, %{
        number: 2,
        html_url: "https://github.test/2",
        title: "Bug",
        state: "closed"
      })
    end)

    assert {:ok, %{number: 2, state: "closed"}} = Client.close_issue("org/repo", 2, "token")
  end

  test "list new issues and fetch helpers use expected REST paths" do
    Req.Test.stub(__MODULE__, fn
      %{method: "GET", request_path: "/repos/org/repo/issues"} = conn ->
        assert %{"since" => "2026-04-24T20:00:00Z", "sort" => "updated"} =
                 URI.decode_query(conn.query_string)

        Req.Test.json(conn, [
          %{
            number: 3,
            html_url: "https://github.test/3",
            title: "Third",
            state: "open",
            updated_at: "2026-04-24T21:00:00Z"
          }
        ])

      %{method: "GET", request_path: "/search/issues"} = conn ->
        assert %{
                 "order" => "asc",
                 "per_page" => "100",
                 "q" => "repo:org/repo is:pr updated:>=2026-04-29T10:00:00Z",
                 "sort" => "updated"
               } = URI.decode_query(conn.query_string)

        Req.Test.json(conn, %{
          total_count: 1,
          items: [
            %{
              number: 7,
              html_url: "https://github.test/pulls/7",
              title: "Seventh",
              state: "open",
              updated_at: "2026-04-29T10:02:00Z"
            }
          ]
        })

      %{method: "GET", request_path: "/user"} = conn ->
        Req.Test.json(conn, %{login: "octocat"})

      %{method: "GET", request_path: "/app/installations/42"} = conn ->
        Req.Test.json(conn, %{id: 42})
    end)

    assert {:ok, [%{number: 3, updated_at: "2026-04-24T21:00:00Z"}]} =
             Client.list_new_issues("org/repo", "2026-04-24T20:00:00Z", "token")

    assert {:ok, [%{number: 7, updated_at: "2026-04-29T10:02:00Z"}]} =
             Client.list_updated_pull_requests("org/repo", "2026-04-29T10:00:00Z", "token")

    assert {:ok, %{"login" => "octocat"}} = Client.fetch_authenticated_user("token")
    assert {:ok, %{"id" => 42}} = Client.fetch_installation(42, "token")
  end

  test "normalizes list and issue mutation error responses" do
    Req.Test.stub(__MODULE__, fn
      %{method: "GET"} = conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{message: "Not Found"})

      %{method: "POST"} = conn ->
        conn
        |> Plug.Conn.put_status(422)
        |> Req.Test.json(%{message: "Validation Failed"})

      %{method: "PATCH"} = conn ->
        conn
        |> Plug.Conn.put_status(422)
        |> Req.Test.json(%{message: "Validation Failed"})
    end)

    assert {:error, %Error.ProviderError{status: 404, details: %{message: "Not Found"}}} =
             Client.list_issues("org/missing", "open", "token")

    assert {:error, %Error.ProviderError{status: 404, details: %{message: "Not Found"}}} =
             Client.get_repository("org", "missing", "token")

    assert {:error, %Error.ProviderError{status: 422, details: %{message: "Validation Failed"}}} =
             Client.create_issue("org/repo", %{title: ""}, "token")

    assert {:error, %Error.ProviderError{status: 422, details: %{message: "Validation Failed"}}} =
             Client.update_issue("org/repo", 2, %{title: ""}, "token")

    assert {:error, %Error.ProviderError{status: 422, details: %{message: "Validation Failed"}}} =
             Client.update_pull_request("org/repo", 5, %{title: ""}, "token")
  end

  test "normalizes issue comment mutation error responses" do
    Req.Test.stub(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(422)
      |> Req.Test.json(%{message: "Validation Failed"})
    end)

    assert {:error, %Error.ProviderError{status: 422, details: %{message: "Validation Failed"}}} =
             Client.create_issue_comment("org/repo", 2, "", "token")
  end
end
