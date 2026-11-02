defmodule Jido.Connect.Jira.Client.IssueSearchTest do
  use ExUnit.Case, async: false

  # Replays the enhanced-search responses that the live test "reads the
  # prepared issue by key and by numeric ID and follows the enhanced search"
  # recorded from the test site for `@jql` with two issues per page:
  #
  #   * `issue_context.4`: JCL-1 and JCL-2, `isLast: false`, a token
  #   * `issue_context.5`: JCL-3 and JCL-4, `isLast: false`, a token
  #   * `issue_context.6`: JCL-5, `isLast: true`, no token
  #   * `issue_context.8`: the 400 answer to a tampered token
  #
  # The test site returns no empty or malformed pages. Tests that need one
  # derive it from a recorded page by changing only the part under test.

  alias Jido.Connect.{Connection, Error}
  alias Jido.Connect.Jira
  alias Jido.Connect.Jira.Client
  alias Jido.Connect.Jira.Client.{IssueSearch, Request}
  alias Jido.Connect.TestSupport.LiveSmoke

  @jql "project = JCL AND key <= JCL-5 ORDER BY key ASC"

  setup {Req.Test, :verify_on_exit!}

  setup do
    previous = Application.get_env(:jido_connect_jira, :jira_req_options)
    Application.put_env(:jido_connect_jira, :jira_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      if previous do
        Application.put_env(:jido_connect_jira, :jira_req_options, previous)
      else
        Application.delete_env(:jido_connect_jira, :jira_req_options)
      end
    end)
  end

  test "posts the JQL, the field list, the page size and the forwarded token" do
    token = page(4)["nextPageToken"]

    expect_page(page(5), fn body ->
      assert body == %{
               "jql" => @jql,
               "fields" => ["summary", "duedate"],
               "maxResults" => 2,
               "nextPageToken" => token
             }
    end)

    assert {:ok, result} =
             Client.search_issues(@jql, api_token_request(),
               fields: ["summary", "duedate"],
               max_results: 2,
               next_page_token: token
             )

    assert %{
             issues: [%{key: "JCL-3", id: "46098"}, %{key: "JCL-4", id: "46099"}],
             next_page_token: next_token,
             is_last: false,
             max_results: 2
           } = result

    assert next_token == page(5)["nextPageToken"]
    refute Map.has_key?(result, :total)
    refute Map.has_key?(result, :start_at)
  end

  test "requests the default fields and no token for the first page" do
    for fields <- [nil, []] do
      expect_page(page(4), fn body ->
        assert body == %{
                 "jql" => @jql,
                 "fields" => IssueSearch.default_fields(),
                 "maxResults" => 50
               }
      end)

      assert {:ok, %{issues: [%{key: "JCL-1"}, %{key: "JCL-2"}]}} =
               Client.search_issues(@jql, api_token_request(), fields: fields)
    end

    assert IssueSearch.default_fields() ==
             ~w(summary status assignee updated description project duedate)
  end

  test "returns the issue context of each issue and keeps null fields apart from missing ones" do
    expect_page(page(4))
    expect_page(page(5))

    assert {:ok, %{issues: [first, _second]}} = Client.search_issues(@jql, api_token_request())

    assert %{
             id: "46096",
             key: "JCL-1",
             url: "https://example.atlassian.net/rest/api/3/issue/46096",
             project: %{key: "JCL"},
             status: %{name: "In Progress"},
             assignee: %{account_id: "account-1"},
             due_date: "2026-11-20",
             description_unsupported_nodes: [],
             missing_fields: []
           } = first

    assert first.description =~ ~r/^Live-test issue\n/

    assert {:ok, %{issues: [third | _]}} =
             Client.search_issues(@jql, api_token_request(),
               fields: IssueSearch.default_fields() ++ ["parent"],
               next_page_token: page(4)["nextPageToken"]
             )

    assert %{key: "JCL-3", description: nil, assignee: nil, due_date: nil} = third
    assert third.missing_fields == ["parent"]
  end

  test "lists a navigable field that the page leaves out, apart from one Jira returns as null" do
    # `issue_fields` answers `*navigable` for JCL-3, whose due date is null.
    # The copy without `duedate` stands for a site that hides the field.
    expect_page(page("issue_fields"), fn body -> assert body["fields"] == ["*navigable"] end)
    expect_page(without_fields(page("issue_fields"), ["duedate"]))

    assert {:ok, %{issues: [%{key: "JCL-3", due_date: nil, missing_fields: []}]}} =
             Client.search_issues(@jql, api_token_request(), fields: ["*navigable"])

    assert {:ok, %{issues: [%{key: "JCL-3", due_date: nil, missing_fields: ["duedate"]}]}} =
             Client.search_issues(@jql, api_token_request(), fields: ["*navigable"])
  end

  test "starts a field list of only exclusions from the navigable fields" do
    # Enhanced search answers `-description` with the navigable fields except
    # description, so the non-navigable `timetracking` is not missing.
    expect_page(without_fields(page("issue_fields"), ["description", "duedate"]), fn body ->
      assert body["fields"] == ["-description"]
    end)

    assert {:ok, %{issues: [%{key: "JCL-3", missing_fields: ["duedate"]}]}} =
             Client.search_issues(@jql, api_token_request(), fields: ["-description"])
  end

  test "returns the reporter as a plain map, so the page encodes as JSON" do
    # The recorded JCL-3 in `issue_fields` was reported by the test user.
    expect_page(page("issue_fields"))

    assert {:ok, result} = Client.search_issues(@jql, api_token_request(), fields: ["*navigable"])

    assert %{
             issues: [
               %{reporter: %{account_id: "account-1", display_name: "Person 1"} = reporter}
             ]
           } =
             result

    refute is_struct(reporter)
    assert {:ok, _json} = Jason.encode(result)
  end

  test "sends no token for an empty next_page_token" do
    # Tool-calling models often fill an optional string with "".
    expect_page(page(4), fn body -> refute Map.has_key?(body, "nextPageToken") end)

    assert {:ok, %{issues: [%{key: "JCL-1"}, %{key: "JCL-2"}]}} =
             Client.search_issues(@jql, api_token_request(), next_page_token: "")
  end

  test "adds the issue key to a field list that names only id" do
    # `id` alone returns bare issue IDs, which do not normalize without a key.
    # `issue_fields.3` answers `["id", "key"]` with key and `self` but no
    # `fields` object.
    for fields <- [["id"], ["id", "-description"]] do
      expect_page(page("issue_fields.3"), fn body ->
        assert body["fields"] == fields ++ ["key"]
      end)

      assert {:ok, %{issues: [%{id: "46098", key: "JCL-3", missing_fields: []}]}} =
               Client.search_issues(@jql, api_token_request(), fields: fields)
    end
  end

  test "follows two pages with an empty non-final page in between and yields every issue once" do
    # The middle page is the recorded second page without its issues: Jira can
    # answer a non-final page with no issues, and the test site does not.
    empty = Map.put(page(5), "issues", [])

    for {response, expected_token} <- [
          {page(4), nil},
          {empty, page(4)["nextPageToken"]},
          {page(6), page(5)["nextPageToken"]}
        ] do
      expect_page(response, fn body -> assert body["nextPageToken"] == expected_token end)
    end

    pages =
      follow(fn token ->
        Client.search_issues(@jql, api_token_request(), max_results: 2, next_page_token: token)
      end)

    assert [
             %{is_last: false, issues: [_, _]},
             %{is_last: false, issues: []},
             %{is_last: true, next_page_token: nil, issues: [_]}
           ] = pages

    assert pages |> Enum.flat_map(& &1.issues) |> Enum.map(& &1.key) == [
             "JCL-1",
             "JCL-2",
             "JCL-5"
           ]
  end

  test "ends on isLast true" do
    expect_page(page(6))

    assert {:ok, %{is_last: true, next_page_token: nil, issues: [%{key: "JCL-5"}]}} =
             Client.search_issues(@jql, api_token_request(), next_page_token: "token")

    # A token next to `isLast: true` does not continue the search. Derived from
    # the recorded last page with the token of the page before it.
    expect_page(Map.put(page(6), "nextPageToken", page(5)["nextPageToken"]))

    assert {:ok, %{is_last: true, next_page_token: nil}} =
             Client.search_issues(@jql, api_token_request(), next_page_token: "token")
  end

  test "a failed later page returns an error, not an empty success" do
    expect_page(page(4))

    Req.Test.expect(__MODULE__, fn conn ->
      conn
      |> Plug.Conn.put_status(400)
      |> Req.Test.json(page(8))
    end)

    assert {:ok, %{next_page_token: token}} = Client.search_issues(@jql, api_token_request())

    assert {:error,
            %Error.ProviderError{
              provider: :jira,
              status: 400,
              details: %{message: "The provided next page token is invalid or expired."}
            }} = Client.search_issues(@jql, api_token_request(), next_page_token: token)

    Req.Test.expect(__MODULE__, &Req.Test.transport_error(&1, :timeout))

    assert {:error, %Error.ProviderError{provider: :jira, reason: :request_error}} =
             Client.search_issues(@jql, api_token_request(), next_page_token: token)
  end

  test "a malformed later page returns an error that names the offending key" do
    # Each page is the recorded second page with one part broken.
    [first_issue | other_issues] = page(5)["issues"]

    # A nested issue field that is not an object.
    nested =
      for key <- ~w(status assignee reporter project issuetype priority) do
        issue = put_in(first_issue, ["fields", key], "JCL")
        {Map.put(page(5), "issues", [issue | other_issues]), "issues"}
      end

    cases =
      [
        {Map.delete(page(5), "issues"), "issues"},
        {Map.put(page(5), "issues", %{}), "issues"},
        {Map.put(page(5), "issues", [Map.delete(first_issue, "key") | other_issues]), "issues"},
        {Map.put(page(5), "issues", ["JCL-3" | other_issues]), "issues"},
        {Map.delete(page(5), "isLast"), "isLast"},
        {Map.put(page(5), "isLast", "false"), "isLast"},
        {Map.delete(page(5), "nextPageToken"), "nextPageToken"},
        {Map.put(page(5), "nextPageToken", ""), "nextPageToken"},
        {Map.put(page(5), "nextPageToken", 42), "nextPageToken"}
      ] ++ nested

    for {body, field} <- cases do
      expect_page(body)

      assert {:error,
              %Error.ProviderError{
                reason: :invalid_response,
                message: "Jira issue search response was invalid",
                details: %{field: ^field}
              }} = Client.search_issues(@jql, api_token_request(), next_page_token: "token")
    end
  end

  test "rejects start_at other than 0 before any request" do
    for start_at <- [50, 1, -1] do
      assert {:error, %Error.ValidationError{reason: :deprecated_start_at, subject: :start_at}} =
               Client.search_issues(@jql, api_token_request(), start_at: start_at)
    end

    expect_page(page(4), fn body -> refute Map.has_key?(body, "startAt") end)
    assert {:ok, _page} = Client.search_issues(@jql, api_token_request(), start_at: 0)
  end

  test "uses Basic auth on the site endpoint and Bearer auth on the OAuth cloud endpoint" do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.host == "example.atlassian.net"
      assert conn.request_path == "/rest/api/3/search/jql"

      assert Plug.Conn.get_req_header(conn, "authorization") == [
               "Basic " <> Base.encode64("user@example.com:token")
             ]

      Req.Test.json(conn, page(6))
    end)

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.host == "api.atlassian.com"
      assert conn.request_path == "/ex/jira/cloud-123/rest/api/3/search/jql"
      assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer oauth-token"]
      Req.Test.json(conn, page(6))
    end)

    assert {:ok, %{is_last: true}} = Client.search_issues(@jql, api_token_request())
    assert {:ok, %{is_last: true}} = Client.search_issues(@jql, oauth_request())
  end

  defp follow(fetch, token \\ nil, pages \\ []) do
    assert {:ok, page} = fetch.(token)
    pages = [page | pages]

    if page.is_last, do: Enum.reverse(pages), else: follow(fetch, page.next_page_token, pages)
  end

  defp page(n) when is_integer(n), do: LiveSmoke.fixture!(:jira, "issue_context.#{n}")
  defp page(name) when is_binary(name), do: LiveSmoke.fixture!(:jira, name)

  defp without_fields(page, keys) do
    Map.update!(page, "issues", fn issues ->
      Enum.map(issues, &update_in(&1, ["fields"], fn fields -> Map.drop(fields, keys) end))
    end)
  end

  defp expect_page(body, check \\ fn _body -> :ok end) do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/rest/api/3/search/jql"
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      check.(Jason.decode!(raw))
      Req.Test.json(conn, body)
    end)
  end

  defp api_token_request do
    {:ok, request} = Client.request_context(Jira.TestRuntime.build())
    request
  end

  defp oauth_request do
    connection =
      Connection.new!(%{
        id: "oauth_conn",
        provider: :jira,
        profile: :oauth2_user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: ["read:jira-work"],
        metadata: %{cloud_endpoint: "https://api.atlassian.com/ex/jira/cloud-123"}
      })

    {:ok, request} = Request.new(connection, %{access_token: "oauth-token"})
    request
  end
end
