defmodule Jido.Connect.Jira.LiveSmokeTest do
  @moduledoc """
  Live smoke checks against the Atlassian Cloud test site.

      mix test --only live_smoke

  See `docs/live_smoke_tests.md` for the variables and the recording mode.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect.Jira.{Client, TestRuntime, Webhook}

  @tag env!(["JIRA_SITE", "JIRA_EMAIL", "JIRA_API_TOKEN", "JIRA_PROJECT_KEY"])
  test "reads the test project", %{env: env} do
    LiveSmoke.record({:jido_connect_jira, :jira_req_options}, :jira, "project")

    assert {:ok, request} = request(env)
    assert {:ok, project} = Client.get_project(env["JIRA_PROJECT_KEY"], request)
    assert is_map(project)
  end

  @tag env!(["JIRA_SITE", "JIRA_EMAIL", "JIRA_API_TOKEN", "JIRA_ISSUE_KEY"])
  test "renders the test issue's comments and description with the shared ADF projection",
       %{env: env} do
    # One recording for both reads: the sanitizer learns the comment authors
    # from the first response and then replaces their account IDs and names in
    # the description's mention and the `x-aaccountid` header of the second.
    # Avatar URLs carry e-mail hashes and initials, so they become placeholders.
    LiveSmoke.record({:jido_connect_jira, :jira_req_options}, :jira, "issue_rich_text",
      fields: ~w(16x16 24x24 32x32 48x48)
    )

    assert {:ok, request} = request(env)

    # The fourth comment of the test issue holds an image.
    assert {:ok, %{comments: comments}} =
             Client.list_comments(env["JIRA_ISSUE_KEY"], request, max_results: 4)

    assert [_ | _] =
             with_image = Enum.filter(comments, &("mediaSingle" in &1.body_unsupported_nodes))

    assert Enum.all?(comments -- with_image, &(&1.body_unsupported_nodes == []))

    assert {:ok, %{description: description, description_unsupported_nodes: []}} =
             Client.get_issue(env["JIRA_ISSUE_KEY"], request, fields: ["description"])

    lines = String.split(description, "\n")
    assert length(lines) > 10
    assert Enum.any?(lines, &String.starts_with?(&1, "- "))
    assert Enum.any?(lines, &Regex.match?(~r/^\s*1\. /, &1))
    assert description =~ "@"
  end

  @context_fields ~w(summary description status assignee priority labels duedate project
                     created updated parent)

  @tag env!([
         "JIRA_SITE",
         "JIRA_EMAIL",
         "JIRA_API_TOKEN",
         "JIRA_PROJECT_KEY",
         "JIRA_ISSUE_KEY",
         "JIRA_ISSUE_ID"
       ])
  test "reads the prepared issue by key and by numeric ID and follows the enhanced search",
       %{env: env} do
    # One recording for all reads. The first response, two comments of the
    # test issue, only teaches the sanitizer the test user and the user that
    # the description mentions, so that their account IDs and names are
    # replaced in the issue bodies and in the `x-aaccountid` header. Comment
    # bodies and avatar URLs become placeholders.
    LiveSmoke.record({:jido_connect_jira, :jira_req_options}, :jira, "issue_context",
      fields: ~w(body 16x16 24x24 32x32 48x48)
    )

    assert {:ok, request} = request(env)

    assert {:ok, %{comments: [_, _]}} =
             Client.list_comments(env["JIRA_ISSUE_KEY"], request, start_at: 2, max_results: 2)

    issue_id = env["JIRA_ISSUE_ID"]
    issue_key = env["JIRA_ISSUE_KEY"]
    project_key = env["JIRA_PROJECT_KEY"]

    assert {:ok, by_key} =
             invoke(env, "jira.issue.get", %{issue_key: issue_key, fields: @context_fields})

    assert {:ok, ^by_key} =
             invoke(env, "jira.issue.get", %{issue_key: issue_id, fields: @context_fields})

    assert %{
             id: ^issue_id,
             key: ^issue_key,
             url: url,
             project: %{key: ^project_key},
             status: %{name: status_name},
             assignee: %{account_id: assignee_id},
             description: description,
             description_unsupported_nodes: [],
             due_date: due_date,
             missing_fields: ["parent"]
           } = by_key

    assert String.ends_with?(url, "/rest/api/3/issue/#{issue_id}")
    assert is_binary(status_name) and is_binary(assignee_id)
    assert String.length(description) > 512
    assert due_date =~ ~r/^\d{4}-\d{2}-\d{2}$/

    jql = "project = #{project_key} AND key <= #{project_key}-5 ORDER BY key ASC"
    pages = follow_search(env, %{jql: jql, max_results: 2})

    assert [_, _ | _] = pages
    assert [%{is_last: true} = last | earlier] = Enum.reverse(pages)
    refute Map.has_key?(last, :next_page_token)
    assert Enum.all?(earlier, &(&1.is_last == false and is_binary(&1.next_page_token)))
    refute Enum.any?(pages, &(Map.has_key?(&1, :total) or Map.has_key?(&1, :start_at)))

    issues = Enum.flat_map(pages, & &1.issues)
    keys = Enum.map(issues, & &1.key)
    assert keys == Enum.uniq(keys)
    assert [first | _] = issues

    assert %{id: ^issue_id, key: ^issue_key, url: ^url, due_date: ^due_date} = first
    assert first.description == description
    assert first.status.name == status_name
    assert first.assignee.account_id == assignee_id

    assert %{key: empty_key, id: empty_id} =
             empty = Enum.find(issues, &is_nil(&1.assignee))

    assert %{description: nil, due_date: nil, missing_fields: []} = empty

    # Jira returns null for the empty context fields and omits `parent`,
    # which a top-level issue does not have.
    assert {:ok, empty_issue} =
             invoke(env, "jira.issue.get", %{issue_key: empty_key, fields: @context_fields})

    assert %{id: ^empty_id, key: ^empty_key, missing_fields: ["parent"]} = empty_issue
    refute Map.has_key?(empty_issue, :description)
    refute Map.has_key?(empty_issue, :assignee)
    refute Map.has_key?(empty_issue, :due_date)

    [%{next_page_token: token} | _] = pages

    assert {:error, %Jido.Connect.Error.ProviderError{status: 400}} =
             invoke(env, "jira.issue.search", %{
               jql: jql,
               max_results: 2,
               next_page_token: String.reverse(token)
             })
  end

  @tag env!(["JIRA_SITE", "JIRA_EMAIL", "JIRA_API_TOKEN", "JIRA_PROJECT_KEY"])
  test "reads the navigable and all fields of an issue without assignee and due date",
       %{env: env} do
    # The test user reported the issue, so the sanitizer learns its account ID
    # from the body before it reaches the `x-aaccountid` header. Avatar URLs
    # carry e-mail hashes and initials, so they become placeholders.
    LiveSmoke.record({:jido_connect_jira, :jira_req_options}, :jira, "issue_fields",
      fields: ~w(16x16 24x24 32x32 48x48)
    )

    jql =
      "project = #{env["JIRA_PROJECT_KEY"]} AND assignee is EMPTY AND duedate is EMPTY " <>
        "ORDER BY key ASC"

    assert {:ok, %{issues: [found]}} =
             invoke(env, "jira.issue.search", %{jql: jql, max_results: 1, fields: ["*navigable"]})

    # `*navigable` returns the empty due date as null and leaves out the
    # non-navigable `timetracking`, which it does not request.
    assert %{key: key, assignee: nil, due_date: nil, missing_fields: []} = found
    assert %{reporter: %{account_id: reporter_id}} = found
    assert is_binary(reporter_id)

    # Without `fields`, Jira returns all fields, the null ones included.
    assert {:ok, issue} = invoke(env, "jira.issue.get", %{issue_key: key})
    assert %{key: ^key, missing_fields: []} = issue
    refute Map.has_key?(issue, :due_date)

    # `id` alone returns bare issue IDs, so the search sends `["id", "key"]`:
    # Jira adds key and `self` but still no `fields` object.
    assert {:ok, %{issues: [%{key: ^key, missing_fields: []}]}} =
             invoke(env, "jira.issue.search", %{jql: jql, max_results: 1, fields: ["id"]})
  end

  @tag env!([
         "JIRA_SITE",
         "JIRA_EMAIL",
         "JIRA_API_TOKEN",
         "JIRA_PROJECT_KEY",
         "JIRA_ISSUE_KEY"
       ])
  test "lists the prepared issue's comments across two pages, the restricted one included",
       %{env: env} do
    # One recording for all reads. The first response, the first four
    # comments, names both comment authors, so the sanitizer knows their
    # account IDs and names before it meets the mention in the first comment
    # on its own and the `x-aaccountid` headers. Avatar URLs carry e-mail
    # hashes and initials, so they become placeholders.
    LiveSmoke.record({:jido_connect_jira, :jira_req_options}, :jira, "comment_list",
      fields: ~w(16x16 24x24 32x32 48x48)
    )

    issue_key = env["JIRA_ISSUE_KEY"]
    list = &invoke(env, "jira.issue.comment.list", Map.put(&1, :issue_key, issue_key))

    assert {:ok, %{issue: ^issue_key, start_at: 0, is_last: false, total: total} = four} =
             list.(%{max_results: 4})

    assert %{max_results: 4, next_start_at: 4, comments: [_, _, _, _]} = four

    assert {:ok, %{start_at: 0, next_start_at: 2, is_last: false} = first} =
             list.(%{max_results: 2})

    assert {:ok, %{start_at: 2, next_start_at: 4, is_last: false} = second} =
             list.(%{start_at: first.next_start_at, max_results: 2})

    assert [_, _] = first.comments
    assert first.total == total and second.total == total
    assert second.issue == issue_key

    # Two pages of two hold the same comments as one page of four, in the
    # same order and with the same visibility.
    assert ids_and_visibility(first.comments ++ second.comments) ==
             ids_and_visibility(four.comments)

    # The test user sees the comment restricted to its project role. Jira
    # leaves out the one restricted to administrators.
    assert [%{visibility: %{"type" => "role", "value" => _role}}] =
             Enum.filter(four.comments, &Map.has_key?(&1, :visibility))

    assert [%{body: text, body_unsupported_nodes: ["mediaSingle"]}] =
             Enum.filter(four.comments, &(&1.body_unsupported_nodes != []))

    assert text != ""

    for comment <- four.comments do
      assert %{id: id, url: url, body_adf: %{"type" => "doc"}, author: %{account_id: _}} =
               comment

      assert String.ends_with?(url, "/comment/#{id}")
      assert %{created_at: _, updated_at: _, update_author: %{account_id: _}} = comment
    end

    # The last page ends the list; a page at the end is empty and also final.
    last_start = total - 2

    assert {:ok, %{start_at: ^last_start, is_last: true, comments: [_, _]} = last} =
             list.(%{start_at: last_start, max_results: 2})

    refute Map.has_key?(last, :next_start_at)

    assert {:ok, %{start_at: ^total, is_last: true, comments: []} = past} =
             list.(%{start_at: total, max_results: 2})

    refute Map.has_key?(past, :next_start_at)

    assert {:error, %Jido.Connect.Error.ProviderError{status: 404}} =
             invoke(env, "jira.issue.comment.list", %{
               issue_key: "#{env["JIRA_PROJECT_KEY"]}-999999"
             })
  end

  @tag env!(["JIRA_SITE", "JIRA_EMAIL", "JIRA_API_TOKEN", "JIRA_ISSUE_KEY"])
  test "walks every visible comment of the prepared issue with the default page size",
       %{env: env} do
    issue_key = env["JIRA_ISSUE_KEY"]
    pages = follow_comments(env, %{issue_key: issue_key})

    # The test issue has more comments than one default page of 50.
    assert [%{max_results: 50, is_last: false} | _] = pages
    assert [_, _ | _] = pages

    comments = Enum.flat_map(pages, & &1.comments)
    ids = Enum.map(comments, & &1.id)

    assert length(comments) == hd(pages).total
    assert ids == Enum.uniq(ids)
    assert ids == Enum.sort_by(ids, &String.to_integer/1)

    assert {:ok, %{is_last: true, comments: all}} =
             invoke(env, "jira.issue.comment.list", %{issue_key: issue_key, max_results: 100})

    assert ids_and_visibility(all) == ids_and_visibility(comments)

    assert [%{visibility: %{"type" => "role"}}] =
             Enum.filter(comments, &Map.has_key?(&1, :visibility))
  end

  @tag env!(["JIRA_WEBHOOK_SECRET", "JIRA_CAPTURE_DIR"])
  test "the newest captured delivery replays before and after sanitizing", %{env: env} do
    secret = env["JIRA_WEBHOOK_SECRET"]

    capture =
      env["JIRA_CAPTURE_DIR"]
      |> captures()
      |> Enum.max_by(& &1["captured_at"], fn ->
        flunk("no jira-webhook-*.json capture in JIRA_CAPTURE_DIR")
      end)

    event = capture["body"] |> Jason.decode!() |> Map.fetch!("webhookEvent")

    assert {:ok, %{event: ^event}} = LiveSmoke.replay(capture, webhook: Webhook, secret: secret)

    assert {:ok, %{event: ^event}} =
             capture
             |> LiveSmoke.sanitize_capture(secret: secret)
             |> LiveSmoke.replay(webhook: Webhook)
  end

  @tag env!(["JIRA_WEBHOOK_SECRET", "JIRA_CAPTURE_DIR"])
  test "captured comment deliveries pass their plain-string bodies through", %{env: env} do
    deliveries =
      for capture <- captures(env["JIRA_CAPTURE_DIR"]),
          payload <- [Jason.decode!(capture["body"])],
          payload["webhookEvent"] in ["comment_created", "comment_updated"] do
        assert {:ok, delivery} =
                 LiveSmoke.replay(capture, webhook: Webhook, secret: env["JIRA_WEBHOOK_SECRET"])

        body = get_in(payload, ["comment", "body"])
        assert is_binary(body)
        assert delivery.normalized_signal.comment_body == body
        assert delivery.normalized_signal.comment_body_unsupported_nodes == []
        delivery
      end

    assert [_ | _] = deliveries
  end

  defp request(env) do
    env
    |> runtime()
    |> Client.request_context()
  end

  defp runtime(env) do
    TestRuntime.build(
      site: env["JIRA_SITE"],
      email: env["JIRA_EMAIL"],
      api_token: env["JIRA_API_TOKEN"]
    )
  end

  # Runs a generated action against the site with the built-in client.
  defp invoke(env, action_id, input) do
    runtime = runtime(env)

    lease =
      Jido.Connect.CredentialLease.from_connection!(
        runtime.context.connection,
        runtime.credentials,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second)
      )

    Jido.Connect.invoke(Jido.Connect.Jira, action_id, input,
      context: runtime.context,
      credential_lease: lease,
      policy: __MODULE__.AllowPolicy
    )
  end

  # Follows `next_page_token` until `is_last`, with a bound against a loop.
  defp follow_search(env, input, pages \\ []) do
    assert length(pages) < 10, "the search did not end within 10 pages"
    assert {:ok, page} = invoke(env, "jira.issue.search", input)

    case page do
      %{is_last: true} ->
        Enum.reverse([page | pages])

      %{next_page_token: token} ->
        follow_search(env, Map.put(input, :next_page_token, token), [page | pages])
    end
  end

  # Follows `next_start_at` until `is_last`, with a bound against a loop.
  defp follow_comments(env, input, pages \\ []) do
    assert length(pages) < 10, "the comment list did not end within 10 pages"
    assert {:ok, page} = invoke(env, "jira.issue.comment.list", input)

    case page do
      %{is_last: true} ->
        Enum.reverse([page | pages])

      %{next_start_at: next_start_at} ->
        follow_comments(env, Map.put(input, :start_at, next_start_at), [page | pages])
    end
  end

  defp ids_and_visibility(comments),
    do: Enum.map(comments, &{&1.id, Map.get(&1, :visibility)})

  defmodule AllowPolicy do
    @moduledoc false
    def authorize(_operation, _input, _context, _connection), do: :ok
  end

  defp captures(dir) do
    dir
    |> Path.join("jira-webhook-*.json")
    |> Path.wildcard()
    |> Enum.map(&(&1 |> File.read!() |> Jason.decode!()))
  end
end
