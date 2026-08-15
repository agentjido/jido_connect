defmodule Jido.Connect.GitHub.Client.Issues do
  @moduledoc "GitHub issue and issue-comment API boundary."

  alias Jido.Connect.Polling
  alias Jido.Connect.GitHub.Client.{Params, Response, Transport}

  def list_issues(repo, state, access_token) when is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/repos/#{repo}/issues",
      params: [state: state, sort: "created", direction: "desc", per_page: 100]
    )
    |> Response.handle_list_response()
  end

  def create_issue(repo, attrs, access_token) when is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/repos/#{repo}/issues", json: attrs)
    |> Response.handle_issue_response()
  end

  def update_issue(repo, issue_number, attrs, access_token)
      when is_integer(issue_number) and is_map(attrs) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.patch(url: "/repos/#{repo}/issues/#{issue_number}", json: attrs)
    |> Response.handle_issue_response()
  end

  def add_issue_labels(repo, issue_number, labels, access_token)
      when is_integer(issue_number) and is_list(labels) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/repos/#{repo}/issues/#{issue_number}/labels", json: %{labels: labels})
    |> Response.handle_label_list_response()
  end

  def remove_issue_label(repo, issue_number, label, access_token)
      when is_integer(issue_number) and is_binary(label) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.delete(url: "/repos/#{repo}/issues/#{issue_number}/labels/#{encode_label(label)}")
    |> Response.handle_label_list_response()
  end

  def assign_issue(repo, issue_number, assignees, access_token)
      when is_integer(issue_number) and is_list(assignees) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/repos/#{repo}/issues/#{issue_number}/assignees",
      json: %{assignees: assignees}
    )
    |> Response.handle_issue_assignment_response()
  end

  def create_issue_comment(repo, issue_number, body, access_token)
      when is_integer(issue_number) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/repos/#{repo}/issues/#{issue_number}/comments", json: %{body: body})
    |> Response.handle_comment_response()
  end

  def list_issue_comments(%{repo: repo, issue_number: issue_number} = params, access_token)
      when is_binary(repo) and is_integer(issue_number) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/repos/#{repo}/issues/#{issue_number}/comments",
      params: Params.issue_comment_list_params(params)
    )
    |> Response.handle_comment_list_response()
  end

  def close_issue(repo, number, access_token)
      when is_integer(number) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.patch(
      url: "/repos/#{repo}/issues/#{number}",
      json: %{state: "closed", state_reason: "completed"}
    )
    |> Response.handle_issue_response()
  end

  def list_new_issues(repo, checkpoint, access_token) when is_binary(access_token) do
    params =
      [
        state: "all",
        sort: "updated",
        direction: "asc",
        per_page: 100
      ]
      |> Polling.put_checkpoint_param(:since, checkpoint)

    access_token
    |> Transport.request()
    |> Req.get(url: "/repos/#{repo}/issues", params: params)
    |> Response.handle_list_response()
  end

  defp encode_label(label), do: URI.encode(label, &URI.char_unreserved?/1)
end
