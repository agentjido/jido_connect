defmodule Jido.Connect.Jira.Client.IssueWritePathTest do
  use ExUnit.Case, async: false

  # The issue update, transition, assign and comment-create calls put the
  # issue key or ID into `/rest/api/3/issue/{issueIdOrKey}` as one encoded
  # path segment, like `Client.get_issue/3`. Update, transition and assign
  # answer `204 No Content`; the comment create answers with the first
  # comment of the recorded `comment_list` page.

  alias Jido.Connect.Error
  alias Jido.Connect.Jira
  alias Jido.Connect.Jira.Client
  alias Jido.Connect.TestSupport.LiveSmoke

  @key "JCL-1/../comment?x=1#y z"
  @segment "JCL-1%2F..%2Fcomment%3Fx%3D1%23y%20z"

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

  test "update_issue/3 sends a key with reserved characters as one encoded path segment" do
    expect_write(
      "PUT",
      "/rest/api/3/issue/" <> @segment,
      [@key],
      &Plug.Conn.send_resp(&1, 204, "")
    )

    assert {:ok, %{updated: true}} =
             Client.update_issue(@key, %{summary: "Updated"}, request())
  end

  test "transition_issue/4 sends a key with reserved characters as one encoded path segment" do
    expect_write(
      "POST",
      "/rest/api/3/issue/#{@segment}/transitions",
      [@key, "transitions"],
      &Plug.Conn.send_resp(&1, 204, "")
    )

    assert {:ok, %{transitioned: true}} = Client.transition_issue(@key, "21", request())
  end

  test "assign_issue/3 sends a key with reserved characters as one encoded path segment" do
    expect_write(
      "PUT",
      "/rest/api/3/issue/#{@segment}/assignee",
      [@key, "assignee"],
      &Plug.Conn.send_resp(&1, 204, "")
    )

    assert {:ok, %{assigned: true}} = Client.assign_issue(@key, "account-1", request())
  end

  test "add_comment/3 sends a key with reserved characters as one encoded path segment" do
    # Derived: the first comment of the recorded `comment_list` page stands in
    # for the answer to `POST …/comment`, which no live test recorded.
    %{"comments" => [comment | _rest]} = LiveSmoke.fixture!(:jira, "comment_list")

    expect_write("POST", "/rest/api/3/issue/#{@segment}/comment", [@key, "comment"], fn conn ->
      conn |> Plug.Conn.put_status(201) |> Req.Test.json(comment)
    end)

    assert {:ok, %{id: "42672"}} = Client.add_comment(@key, "Comment text", request())
  end

  test "every write path rejects an identifier that a path would resolve as a dot segment" do
    test = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test, {:jira_called, conn.method, conn.request_path})
      Plug.Conn.send_resp(conn, 204, "")
    end)

    for key <- ["", ".", ".."] do
      for result <- [
            Client.update_issue(key, %{summary: "Updated"}, request()),
            Client.transition_issue(key, "21", request()),
            Client.assign_issue(key, "account-1", request()),
            Client.add_comment(key, "Comment text", request())
          ] do
        assert {:error, %Error.ValidationError{reason: :invalid_issue_key, subject: :issue_key}} =
                 result
      end
    end

    refute_received {:jira_called, _method, _path}
  end

  # `segments` are the decoded path segments after `/rest/api/3/issue`.
  defp expect_write(method, path, segments, respond) do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == method
      assert ["rest", "api", "3", "issue" | encoded] = conn.path_info
      assert Enum.map(encoded, &URI.decode/1) == segments
      assert conn.request_path == path
      assert conn.query_string == ""
      respond.(conn)
    end)
  end

  defp request do
    {:ok, request} = Client.request_context(Jira.TestRuntime.build())
    request
  end
end
