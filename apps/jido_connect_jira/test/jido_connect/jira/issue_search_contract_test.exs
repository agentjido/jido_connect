defmodule Jido.Connect.Jira.IssueSearchContractTest do
  use ExUnit.Case, async: false

  # Contract of `jira.issue.search` after the move to enhanced search: for one
  # release `start_at` stays a deprecated input that accepts only 0, and
  # `total` and `start_at` stay deprecated outputs that are never returned.
  # Responses are the recorded pages `issue_context.4` to `issue_context.6`;
  # see `Jido.Connect.Jira.Client.IssueSearchTest`.

  alias Jido.Connect
  alias Jido.Connect.Error
  alias Jido.Connect.Jira
  alias Jido.Connect.Jira.Client.IssueSearch
  alias Jido.Connect.TestSupport.LiveSmoke

  @jql "project = JCL AND key <= JCL-5 ORDER BY key ASC"

  defmodule AllowPolicy do
    def authorize(_operation, _input, _context, _connection), do: :ok
  end

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

  test "declares start_at and total as deprecated, next_page_token as input and output, is_last as output" do
    {:ok, action} = Connect.action(Jira.integration(), "jira.issue.search")
    input = Map.new(action.input, &{&1.name, &1})
    output = Map.new(action.output, &{&1.name, &1})

    for field <- [input.start_at, output.start_at, output.total] do
      assert field.metadata.deprecated == true
      assert field.description =~ ~r/^Deprecated/
    end

    assert %{type: :integer, default: 0, enum: [0]} = input.start_at
    assert %{type: :string, required?: false} = input.next_page_token
    assert %{type: :string} = output.next_page_token
    assert %{type: :boolean} = output.is_last

    for name <- [:next_page_token, :is_last, :issues, :max_results] do
      refute Map.get(output[name].metadata, :deprecated)
    end

    assert input.fields.default == IssueSearch.default_fields()
  end

  test "returns neither total nor start_at" do
    expect_page(4, fn body ->
      assert body == %{"jql" => @jql, "fields" => IssueSearch.default_fields(), "maxResults" => 2}
    end)

    assert {:ok, result} = invoke(%{jql: @jql, max_results: 2, start_at: 0})

    assert %{
             issues: [%{key: "JCL-1"}, %{key: "JCL-2"}],
             next_page_token: token,
             is_last: false,
             max_results: 2
           } = result

    assert token == page(4)["nextPageToken"]
    refute Map.has_key?(result, :total)
    refute Map.has_key?(result, :start_at)
  end

  test "returns an empty description as an empty text in the issues" do
    # Derived: the recorded first page with JCL-1's description emptied to a
    # document without content. JCL-2's description is null in the recording.
    empty =
      update_in(page(4), ["issues"], fn [first | rest] ->
        [put_in(first, ["fields", "description", "content"], []) | rest]
      end)

    Req.Test.expect(__MODULE__, &Req.Test.json(&1, empty))

    assert {:ok, %{issues: [first, second]}} = invoke(%{jql: @jql, max_results: 2})
    assert %{key: "JCL-1", description: "", description_unsupported_nodes: []} = first
    assert %{key: "JCL-2", description: nil} = second
  end

  test "rejects start_at other than 0 before any request" do
    test = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test, :jira_called)
      Req.Test.json(conn, page(4))
    end)

    for start_at <- [50, 1, -1] do
      assert {:error, %Error.ValidationError{reason: :input, details: %{errors: errors}}} =
               invoke(%{jql: @jql, start_at: start_at})

      assert Enum.any?(errors, &(&1.path == [:start_at]))
    end

    refute_received :jira_called
  end

  test "pages with next_page_token across an empty non-final page and ends on is_last" do
    # The middle page is the recorded second page without its issues.
    empty = Map.put(page(5), "issues", [])

    for {response, token} <- [
          {page(4), nil},
          {empty, page(4)["nextPageToken"]},
          {page(6), page(5)["nextPageToken"]}
        ] do
      Req.Test.expect(__MODULE__, fn conn ->
        {:ok, raw, conn} = Plug.Conn.read_body(conn)
        assert Jason.decode!(raw)["nextPageToken"] == token
        Req.Test.json(conn, response)
      end)
    end

    pages = follow(%{jql: @jql, max_results: 2})

    assert [%{is_last: false}, %{is_last: false, issues: []}, %{is_last: true} = last] = pages
    refute Map.has_key?(last, :next_page_token)

    assert pages |> Enum.flat_map(& &1.issues) |> Enum.map(& &1.key) == [
             "JCL-1",
             "JCL-2",
             "JCL-5"
           ]
  end

  defp follow(input, pages \\ []) do
    assert {:ok, page} = invoke(input)
    pages = [page | pages]

    case page do
      %{is_last: true} -> Enum.reverse(pages)
      %{next_page_token: token} -> follow(Map.put(input, :next_page_token, token), pages)
    end
  end

  defp page(n), do: LiveSmoke.fixture!(:jira, "issue_context.#{n}")

  defp expect_page(n, check) do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "POST"
      assert conn.request_path == "/rest/api/3/search/jql"
      {:ok, raw, conn} = Plug.Conn.read_body(conn)
      check.(Jason.decode!(raw))
      Req.Test.json(conn, page(n))
    end)
  end

  defp invoke(input) do
    runtime = Jira.TestRuntime.build()

    lease =
      Connect.CredentialLease.from_connection!(runtime.context.connection, runtime.credentials,
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
      )

    Connect.invoke(Jira, "jira.issue.search", input,
      context: runtime.context,
      credential_lease: lease,
      policy: AllowPolicy
    )
  end
end
