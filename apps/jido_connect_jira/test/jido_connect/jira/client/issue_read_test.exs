defmodule Jido.Connect.Jira.Client.IssueReadTest do
  use ExUnit.Case, async: false

  # Replays the responses that the live test "reads the prepared issue by key
  # and by numeric ID and follows the enhanced search" recorded from the test
  # site (`test/fixtures/jira/recorded/issue_context*.json`):
  #
  #   * `issue_context.2`: `GET /rest/api/3/issue/JCL-1` with `@fields`
  #   * `issue_context.3`: `GET /rest/api/3/issue/46096`, the same issue by ID
  #   * `issue_context.7`: `GET /rest/api/3/issue/JCL-3`, an issue whose
  #     description, assignee and due date are null
  #
  # Each request asked for `parent`, which a top-level issue does not have, so
  # Jira left it out of `fields`.
  #
  # `issue_fields.2` is the read of JCL-3 without `fields`, so with all
  # fields, from the live test "reads the navigable and all fields of an issue
  # without assignee and due date".

  alias Jido.Connect
  alias Jido.Connect.{Connection, Error}
  alias Jido.Connect.Jira
  alias Jido.Connect.Jira.Client
  alias Jido.Connect.Jira.Client.Request
  alias Jido.Connect.TestSupport.LiveSmoke

  @fields ~w(summary description status assignee priority labels duedate project created updated parent)

  defmodule AllowPolicy do
    def authorize(_operation, _input, _context, _connection), do: :ok
  end

  setup {Req.Test, :verify_on_exit!}

  setup do
    previous = Application.get_env(:jido_connect_jira, :jira_req_options)

    Application.put_env(:jido_connect_jira, :jira_req_options,
      plug: {Req.Test, __MODULE__},
      retry: false
    )

    on_exit(fn ->
      if previous do
        Application.put_env(:jido_connect_jira, :jira_req_options, previous)
      else
        Application.delete_env(:jido_connect_jira, :jira_req_options)
      end
    end)
  end

  describe "Client.get_issue/3" do
    test "returns the issue context of the recorded issue read by key" do
      expect_issue("/rest/api/3/issue/JCL-1", "issue_context.2")

      assert {:ok, issue} = Client.get_issue("JCL-1", api_token_request(), fields: @fields)

      assert %{
               id: "46096",
               key: "JCL-1",
               url: "https://example.atlassian.net/rest/api/3/issue/46096",
               project: %{key: "JCL", id: "10882"},
               assignee: %{account_id: "account-1", display_name: "Person 1"},
               status: %{name: "In Progress"},
               due_date: "2026-11-20",
               description_unsupported_nodes: [],
               missing_fields: ["parent"]
             } = issue

      assert ["Live-test issue", _ | _] = String.split(issue.description, "\n")
      refute is_struct(issue.assignee) or is_struct(issue.status)
    end

    test "reads the same issue by numeric ID" do
      expect_issue("/rest/api/3/issue/JCL-1", "issue_context.2")
      expect_issue("/rest/api/3/issue/46096", "issue_context.3")

      assert {:ok, by_key} = Client.get_issue("JCL-1", api_token_request(), fields: @fields)
      assert {:ok, by_id} = Client.get_issue("46096", api_token_request(), fields: @fields)
      assert by_id == by_key
    end

    test "keeps fields Jira returns as null apart from requested fields it leaves out" do
      expect_issue("/rest/api/3/issue/JCL-3", "issue_context.7")

      assert {:ok, issue} = Client.get_issue("JCL-3", api_token_request(), fields: @fields)

      assert %{
               key: "JCL-3",
               description: nil,
               description_unsupported_nodes: nil,
               assignee: nil,
               due_date: nil,
               missing_fields: ["parent"]
             } = issue
    end

    test "keeps an empty description as an empty text, apart from a missing one" do
      # Derived: the recorded JCL-1 read once with its description emptied to
      # a document without content and once without `description`. The null
      # description of JCL-3 is the test above.
      Req.Test.expect(__MODULE__, &Req.Test.json(&1, with_empty_description("issue_context.2")))
      Req.Test.expect(__MODULE__, &Req.Test.json(&1, without_description("issue_context.2")))

      assert {:ok, empty} = Client.get_issue("JCL-1", api_token_request(), fields: @fields)
      assert {:ok, missing} = Client.get_issue("JCL-1", api_token_request(), fields: @fields)

      assert %{description: "", description_unsupported_nodes: [], missing_fields: ["parent"]} =
               empty

      assert %{
               description: nil,
               description_unsupported_nodes: nil,
               missing_fields: ["description", "parent"]
             } = missing
    end

    test "keeps an image-only description as an empty text and lists mediaSingle" do
      # Derived: the recorded JCL-1 read with the body of the recorded image
      # comment 42675 (`comment_list`) as its description, reduced to the
      # body's `mediaSingle` node.
      image_only = with_image_only_description("issue_context.2")
      Req.Test.expect(__MODULE__, &Req.Test.json(&1, image_only))

      assert {:ok, issue} = Client.get_issue("JCL-1", api_token_request(), fields: @fields)

      assert %{
               description: "",
               description_unsupported_nodes: ["mediaSingle"],
               missing_fields: ["parent"]
             } = issue
    end

    test "lists a requested context field that the payload leaves out" do
      # The test site cannot hide a system field without an administrator
      # change, so this response is the recorded JCL-3 read with `duedate`
      # removed, the way Jira leaves out `parent` in the same recording.
      Req.Test.expect(__MODULE__, &Req.Test.json(&1, without_duedate("issue_context.7")))

      assert {:ok, %{due_date: nil, missing_fields: ["duedate", "parent"]}} =
               Client.get_issue("JCL-3", api_token_request(), fields: @fields)
    end

    test "reads all fields without a field list and lists a read field Jira leaves out" do
      # `issue_fields.2` is the recorded read of JCL-3 without `fields`, so
      # Jira returned all fields, the empty due date as null. The copy without
      # `duedate` stands for a site whose field configuration hides it.
      expect_issue("/rest/api/3/issue/JCL-3", "issue_fields.2", fn conn ->
        refute Map.has_key?(conn.query_params, "fields")
      end)

      Req.Test.expect(__MODULE__, &Req.Test.json(&1, without_duedate("issue_fields.2")))

      assert {:ok, %{key: "JCL-3", due_date: nil, missing_fields: []}} =
               Client.get_issue("JCL-3", api_token_request())

      assert {:ok, %{key: "JCL-3", due_date: nil, missing_fields: ["duedate"]}} =
               Client.get_issue("JCL-3", api_token_request())
    end

    test "sends the requested fields as one comma-separated parameter" do
      expect_issue("/rest/api/3/issue/JCL-1", "issue_context.2", fn conn ->
        assert conn.query_params["fields"] == Enum.join(@fields, ",")
      end)

      assert {:ok, _issue} = Client.get_issue("JCL-1", api_token_request(), fields: @fields)
    end

    test "sends a key with reserved characters as one encoded path segment" do
      key = "JCL-1/../comment?x=1#y z"

      Req.Test.expect(__MODULE__, fn conn ->
        assert ["rest", "api", "3", "issue", segment] = conn.path_info
        assert URI.decode(segment) == key
        assert conn.request_path == "/rest/api/3/issue/JCL-1%2F..%2Fcomment%3Fx%3D1%23y%20z"
        assert conn.query_string == ""
        Req.Test.json(conn, LiveSmoke.fixture!(:jira, "issue_context.2"))
      end)

      assert {:ok, %{key: "JCL-1"}} = Client.get_issue(key, api_token_request())
    end

    test "rejects an identifier that a path would resolve as a dot segment" do
      for key <- ["", ".", ".."] do
        assert {:error, %Error.ValidationError{reason: :invalid_issue_key, subject: :issue_key}} =
                 Client.get_issue(key, api_token_request())
      end
    end

    test "uses Basic auth on the site endpoint" do
      expect_issue("/rest/api/3/issue/10001", "issue_context.3", fn conn ->
        assert conn.host == "example.atlassian.net"

        assert Plug.Conn.get_req_header(conn, "authorization") == [
                 basic("user@example.com", "token")
               ]
      end)

      assert {:ok, %{id: "46096"}} = Client.get_issue("10001", api_token_request())
    end

    test "uses Bearer auth on the OAuth cloud endpoint and keeps its path" do
      expect_issue("/ex/jira/cloud-123/rest/api/3/issue/10001", "issue_context.3", fn conn ->
        assert conn.host == "api.atlassian.com"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer oauth-token"]
      end)

      assert {:ok, %{id: "46096"}} = Client.get_issue("10001", oauth_request())
    end
  end

  describe "jira.issue.get" do
    test "returns ID, URL, description and due date of the recorded issue" do
      expect_issue("/rest/api/3/issue/JCL-1", "issue_context.2")

      assert {:ok, issue} = invoke(%{issue_key: "JCL-1", fields: @fields})

      assert %{
               id: "46096",
               key: "JCL-1",
               url: "https://example.atlassian.net/rest/api/3/issue/46096",
               project: %{key: "JCL"},
               assignee: %{account_id: "account-1"},
               status: %{name: "In Progress"},
               due_date: "2026-11-20",
               description_unsupported_nodes: [],
               missing_fields: ["parent"]
             } = issue

      assert issue.description =~ ~r/^Live-test issue\n/
    end

    test "omits null fields and lists only the fields Jira left out" do
      expect_issue("/rest/api/3/issue/JCL-3", "issue_context.7")

      assert {:ok, issue} = invoke(%{issue_key: "JCL-3", fields: @fields})

      assert %{key: "JCL-3", id: "46098", missing_fields: ["parent"]} = issue
      refute Map.has_key?(issue, :description)
      refute Map.has_key?(issue, :assignee)
      refute Map.has_key?(issue, :due_date)
    end

    test "returns an empty description as an empty text and leaves out a missing one" do
      # Derived: the recorded JCL-1 read once with its description emptied to
      # a document without content and once without `description`.
      Req.Test.expect(__MODULE__, &Req.Test.json(&1, with_empty_description("issue_context.2")))
      Req.Test.expect(__MODULE__, &Req.Test.json(&1, without_description("issue_context.2")))

      assert {:ok, %{key: "JCL-1", description: "", description_unsupported_nodes: []}} =
               invoke(%{issue_key: "JCL-1", fields: @fields})

      assert {:ok, %{key: "JCL-1", missing_fields: ["description", "parent"]} = missing} =
               invoke(%{issue_key: "JCL-1", fields: @fields})

      refute Map.has_key?(missing, :description)
      refute Map.has_key?(missing, :description_unsupported_nodes)
    end

    test "reads an issue by numeric ID" do
      expect_issue("/rest/api/3/issue/46096", "issue_context.3")

      assert {:ok, %{id: "46096", key: "JCL-1"}} = invoke(%{issue_key: "46096", fields: @fields})
    end

    test "reads all fields by default and lists none of them as missing" do
      expect_issue("/rest/api/3/issue/JCL-3", "issue_fields.2", fn conn ->
        refute Map.has_key?(conn.query_params, "fields")
      end)

      assert {:ok, %{key: "JCL-3", id: "46098", missing_fields: []} = issue} =
               invoke(%{issue_key: "JCL-3"})

      refute Map.has_key?(issue, :due_date)
    end
  end

  defp without_duedate(fixture) do
    update_in(LiveSmoke.fixture!(:jira, fixture), ["fields"], &Map.delete(&1, "duedate"))
  end

  defp without_description(fixture) do
    update_in(LiveSmoke.fixture!(:jira, fixture), ["fields"], &Map.delete(&1, "description"))
  end

  defp with_empty_description(fixture) do
    put_in(LiveSmoke.fixture!(:jira, fixture), ["fields", "description", "content"], [])
  end

  defp with_image_only_description(fixture) do
    %{"comments" => comments} = LiveSmoke.fixture!(:jira, "comment_list")
    %{"body" => %{"content" => content} = body} = Enum.find(comments, &(&1["id"] == "42675"))
    [image] = Enum.filter(content, &(&1["type"] == "mediaSingle"))

    put_in(
      LiveSmoke.fixture!(:jira, fixture),
      ["fields", "description"],
      %{body | "content" => [image]}
    )
  end

  defp expect_issue(path, fixture, check \\ fn _conn -> :ok end) do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == path
      check.(Plug.Conn.fetch_query_params(conn))
      Req.Test.json(conn, LiveSmoke.fixture!(:jira, fixture))
    end)
  end

  defp invoke(input) do
    runtime = Jira.TestRuntime.build()

    lease =
      Connect.CredentialLease.from_connection!(runtime.context.connection, runtime.credentials,
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
      )

    Connect.invoke(Jira, "jira.issue.get", input,
      context: runtime.context,
      credential_lease: lease,
      policy: AllowPolicy
    )
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

  defp basic(email, token), do: "Basic " <> Base.encode64("#{email}:#{token}")
end
