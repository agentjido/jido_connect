defmodule Jido.Connect.Jira.Client.CommentListTest do
  use ExUnit.Case, async: false

  # Replays the responses that the live test "lists the prepared issue's
  # comments across two pages, the restricted one included" recorded from the
  # test site for `GET /rest/api/3/issue/JCL-1/comment`
  # (`test/fixtures/jira/recorded/comment_list*.json`):
  #
  #   * `comment_list`: `startAt` 0, `maxResults` 4: 42672 with a list and a
  #     mention, 42673 restricted to a project role, 42675 with an image and
  #     42676 with twelve paragraphs; 54 comments in total
  #   * `comment_list.2` and `.3`: the same four comments as two pages of two
  #   * `comment_list.4`: `startAt` 52, the last two comments
  #   * `comment_list.5`: `startAt` 54, the empty page at the end
  #
  # The test site returns no short or empty non-final page and no malformed
  # page or body. Tests that need one derive it from a recorded page by
  # changing only the part under test.

  alias Jido.Connect.{Connection, Error}
  alias Jido.Connect.Jira
  alias Jido.Connect.Jira.Client
  alias Jido.Connect.Jira.Client.Request
  alias Jido.Connect.TestSupport.LiveSmoke

  @path "/rest/api/3/issue/JCL-1/comment"

  @person_1 %{
    account_id: "account-1",
    account_type: "atlassian",
    active: true,
    avatar_urls: %{
      "16x16" => "16x16-1",
      "24x24" => "24x24-1",
      "32x32" => "32x32-1",
      "48x48" => "48x48-1"
    },
    display_name: "Person 1",
    email: "person-1@example.com",
    time_zone: "Europe/Berlin"
  }

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

  describe "request" do
    test "asks for one page oldest first, without rendered HTML" do
      expect_page(page(3), fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == @path

        assert conn.query_params == %{
                 "startAt" => "2",
                 "maxResults" => "2",
                 "orderBy" => "created"
               }
      end)

      assert {:ok, %{start_at: 2}} =
               Client.list_comments("JCL-1", api_token_request(), start_at: 2, max_results: 2)
    end

    test "sends startAt 0 and maxResults 50 by default" do
      expect_page(page(1), fn conn ->
        assert conn.query_params == %{
                 "startAt" => "0",
                 "maxResults" => "50",
                 "orderBy" => "created"
               }
      end)

      assert {:ok, %{start_at: 0}} = Client.list_comments("JCL-1", api_token_request())
    end

    test "sends a key with reserved characters as one encoded path segment" do
      key = "JCL-1/../x?y=1#z w"

      expect_page(page(1), fn conn ->
        assert ["rest", "api", "3", "issue", segment, "comment"] = conn.path_info
        assert URI.decode(segment) == key
        assert conn.request_path == "/rest/api/3/issue/JCL-1%2F..%2Fx%3Fy%3D1%23z%20w/comment"
      end)

      assert {:ok, %{issue: ^key}} = Client.list_comments(key, api_token_request())
    end

    test "rejects an identifier that a path would resolve as a dot segment" do
      for key <- ["", ".", ".."] do
        assert {:error, %Error.ValidationError{reason: :invalid_issue_key, subject: :issue_key}} =
                 Client.list_comments(key, api_token_request())
      end
    end

    test "rejects page sizes outside 1 to 100 and a negative offset before any request" do
      for max_results <- [0, 101, -1, nil, "50", 2.0] do
        assert {:error,
                %Error.ValidationError{
                  reason: :invalid_max_results,
                  subject: :max_results,
                  details: %{minimum: 1, maximum: 100}
                }} =
                 Client.list_comments("JCL-1", api_token_request(), max_results: max_results)
      end

      for start_at <- [-1, nil, "0"] do
        assert {:error, %Error.ValidationError{reason: :invalid_start_at, subject: :start_at}} =
                 Client.list_comments("JCL-1", api_token_request(), start_at: start_at)
      end

      for max_results <- [1, 100] do
        expect_page(page(1), fn conn ->
          assert conn.query_params["maxResults"] == to_string(max_results)
        end)

        assert {:ok, _page} =
                 Client.list_comments("JCL-1", api_token_request(), max_results: max_results)
      end
    end

    test "uses Basic auth on the site endpoint and Bearer auth on the OAuth cloud endpoint" do
      expect_page(page(4), fn conn ->
        assert conn.host == "example.atlassian.net"
        assert conn.request_path == "/rest/api/3/issue/46096/comment"

        assert Plug.Conn.get_req_header(conn, "authorization") == [
                 "Basic " <> Base.encode64("user@example.com:token")
               ]
      end)

      expect_page(page(4), fn conn ->
        assert conn.host == "api.atlassian.com"
        assert conn.request_path == "/ex/jira/cloud-123/rest/api/3/issue/46096/comment"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer oauth-token"]
      end)

      assert {:ok, %{is_last: true}} = Client.list_comments("46096", api_token_request())
      assert {:ok, %{is_last: true}} = Client.list_comments("46096", oauth_request())
    end
  end

  describe "comments" do
    test "keep ID, URL, text, original ADF, authors, timestamps and visibility" do
      raw = page(1)["comments"]
      expect_page(page(1))

      assert {:ok,
              %{
                issue: "JCL-1",
                start_at: 0,
                max_results: 4,
                total: 54,
                comments: [first, restricted, _image, _long]
              }} = Client.list_comments("JCL-1", api_token_request(), max_results: 4)

      # Exact maps: a comment without visibility or rendered body has no such keys.
      assert first == %{
               id: "42672",
               url: "https://example.atlassian.net/rest/api/3/issue/46096/comment/42672",
               body:
                 "First comment with a list and a mention of @Person 2.\n" <>
                   "- Comment list item one\n- Comment list item two",
               body_adf: Enum.at(raw, 0)["body"],
               body_unsupported_nodes: [],
               author: @person_1,
               update_author: @person_1,
               created_at: "2026-10-30T20:16:45.703+0100",
               updated_at: "2026-10-30T20:16:45.703+0100",
               jsd_public: true
             }

      assert restricted == %{
               id: "42673",
               url: "https://example.atlassian.net/rest/api/3/issue/46096/comment/42673",
               body: "Restricted to the role 'Ext. Mitarbeiter', which the test user has.",
               body_adf: Enum.at(raw, 1)["body"],
               body_unsupported_nodes: [],
               author: @person_1,
               update_author: @person_1,
               created_at: "2026-10-30T20:16:46.281+0100",
               updated_at: "2026-10-30T20:16:46.281+0100",
               visibility: %{
                 "type" => "role",
                 "value" => "Ext. Mitarbeiter",
                 "identifier" => "Ext. Mitarbeiter"
               },
               jsd_public: true
             }
    end

    test "a body with an image returns its text and lists mediaSingle" do
      raw = page(1)["comments"]
      expect_page(page(1))

      assert {:ok, %{comments: [_, _, image, _]}} =
               Client.list_comments("JCL-1", api_token_request(), max_results: 4)

      assert %{
               id: "42675",
               body: "Comment with an embedded image:",
               body_unsupported_nodes: ["mediaSingle"],
               body_adf: %{"content" => [_paragraph, %{"type" => "mediaSingle"}]} = adf
             } = image

      assert adf == Enum.at(raw, 2)["body"]
    end

    test "a long body survives in full, as text and as ADF" do
      raw = page(1)["comments"]
      expect_page(page(1))

      assert {:ok, %{comments: [_, _, _, long]}} =
               Client.list_comments("JCL-1", api_token_request(), max_results: 4)

      lines =
        for n <- 1..12 do
          "Line #{String.pad_leading(to_string(n), 2, "0")} of the long live-test text " <>
            "for a long comment: Umlaute äöü ß, Euro €, Dash –."
        end

      assert %{id: "42676", body_unsupported_nodes: [], author: %{account_id: "account-2"}} =
               long

      assert long.body == Enum.join(lines, "\n")
      assert long.body_adf == Enum.at(raw, 3)["body"]
    end

    test "missing, empty and malformed bodies stay distinguishable" do
      # Each page is the recorded second page with the first comment's body
      # removed, emptied to a document without content, or broken.
      [comment | rest] = page(3)["comments"]

      expect_page(Map.put(page(3), "comments", [Map.delete(comment, "body") | rest]))
      expect_page(Map.put(page(3), "comments", [put_in(comment, ["body", "content"], []) | rest]))

      broken =
        update_in(comment, ["body", "content"], fn [first | others] ->
          [Map.put(first, "content", %{}) | others]
        end)

      expect_page(Map.put(page(3), "comments", [broken | rest]))

      assert {:ok, %{comments: [missing | _]}} = list(start_at: 2, max_results: 2)
      assert %{id: "42675"} = missing
      refute Map.has_key?(missing, :body)
      refute Map.has_key?(missing, :body_adf)
      refute Map.has_key?(missing, :body_unsupported_nodes)

      assert {:ok, %{comments: [empty | _]}} = list(start_at: 2, max_results: 2)

      assert %{
               id: "42675",
               body: "",
               body_unsupported_nodes: [],
               body_adf: %{"type" => "doc", "version" => 1, "content" => []}
             } = empty

      assert {:error,
              %Error.ProviderError{
                reason: :invalid_response,
                message: "Jira comment list response was invalid",
                details: %{field: "body", comment_id: "42675", adf_reason: :invalid_adf}
              }} = list(start_at: 2, max_results: 2)
    end
  end

  describe "pages" do
    test "next_start_at is the returned startAt plus the returned count" do
      expect_page(page(2))
      expect_page(page(3))

      assert {:ok,
              %{
                start_at: 0,
                max_results: 2,
                total: 54,
                is_last: false,
                next_start_at: 2,
                comments: [%{id: "42672"}, %{id: "42673"}]
              }} = list(max_results: 2)

      # Jira's startAt counts, not the requested one.
      assert {:ok, %{start_at: 2, is_last: false, next_start_at: 4}} =
               list(start_at: 1, max_results: 2)
    end

    test "two pages of two hold the comments of one page of four" do
      expect_page(page(2))
      expect_page(page(3))
      expect_page(page(1))

      assert {:ok, %{next_start_at: next_start_at, comments: first}} = list(max_results: 2)
      assert {:ok, %{comments: second}} = list(start_at: next_start_at, max_results: 2)
      assert {:ok, %{comments: four}} = list(max_results: 4)

      assert first ++ second == four
    end

    test "a short non-final page stays non-final" do
      # The recorded second page without its last comment: fewer comments
      # than maxResults, but far from total.
      short = Map.update!(page(3), "comments", &Enum.take(&1, 1))
      expect_page(short)

      assert {:ok, %{start_at: 2, max_results: 2, is_last: false, next_start_at: 3}} =
               list(start_at: 2, max_results: 2)
    end

    test "the last page ends the list" do
      expect_page(page(4))

      assert {:ok,
              %{
                start_at: 52,
                total: 54,
                is_last: true,
                next_start_at: nil,
                comments: [%{id: "42725"}, %{id: "42726"}]
              }} = list(start_at: 52, max_results: 2)
    end

    test "an empty final page succeeds" do
      expect_page(page(5))

      assert {:ok, %{start_at: 54, total: 54, is_last: true, next_start_at: nil, comments: []}} =
               list(start_at: 54, max_results: 2)
    end

    test "an empty page past the end is final" do
      # The recorded empty page at the end with `total` lowered from 54 to 52,
      # as if two comments had been deleted after the previous page pointed
      # the caller at offset 54.
      expect_page(Map.put(page(5), "total", 52))

      assert {:ok, %{start_at: 54, total: 52, is_last: true, next_start_at: nil, comments: []}} =
               list(start_at: 54, max_results: 2)
    end

    test "an empty non-final page fails" do
      # The recorded second page without its comments, which would point the
      # next call at its own offset.
      expect_page(Map.put(page(3), "comments", []))

      assert {:error,
              %Error.ProviderError{
                reason: :invalid_response,
                message: "Jira comment list response was invalid",
                details: %{field: "comments"}
              }} = list(start_at: 2, max_results: 2)
    end

    test "a malformed page fails and names the offending key" do
      # Each page is the recorded second page with one part broken.
      [comment | rest] = page(3)["comments"]
      with_first = &Map.put(page(3), "comments", [&1 | rest])

      cases = [
        {Map.delete(page(3), "comments"), "comments"},
        {Map.put(page(3), "comments", %{}), "comments"},
        {with_first.("42675"), "comments"},
        {with_first.(Map.delete(comment, "id")), "comments"},
        {with_first.(Map.put(comment, "author", "account-1")), "comments"},
        {with_first.(Map.put(comment, "visibility", "role")), "comments"},
        {Map.delete(page(3), "startAt"), "startAt"},
        {Map.put(page(3), "startAt", -1), "startAt"},
        {Map.put(page(3), "startAt", "2"), "startAt"},
        {Map.delete(page(3), "maxResults"), "maxResults"},
        {Map.put(page(3), "total", nil), "total"},
        {Map.put(page(3), "total", "54"), "total"}
      ]

      for {body, field} <- cases do
        expect_page(body)

        assert {:error,
                %Error.ProviderError{
                  reason: :invalid_response,
                  message: "Jira comment list response was invalid",
                  details: %{field: ^field}
                }} = list(start_at: 2, max_results: 2)
      end

      expect_page([page(3)])

      assert {:error, %Error.ProviderError{reason: :invalid_response}} =
               list(start_at: 2, max_results: 2)
    end
  end

  defp list(opts), do: Client.list_comments("JCL-1", api_token_request(), opts)

  defp page(1), do: LiveSmoke.fixture!(:jira, "comment_list")
  defp page(n), do: LiveSmoke.fixture!(:jira, "comment_list.#{n}")

  defp expect_page(body, check \\ fn _conn -> :ok end) do
    Req.Test.expect(__MODULE__, fn conn ->
      check.(conn)
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
