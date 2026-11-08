defmodule Jido.Connect.GitHub.Client.Evidence do
  @moduledoc "GitHub pull-request review and check-run read boundary."

  alias Jido.Connect.GitHub.Client.{Pagination, Response, Transport}

  def list_pull_request_reviews(%{repo: repo, pull_number: pull_number} = params, access_token)
      when is_binary(repo) and is_integer(pull_number) and is_binary(access_token) do
    with {:ok, page} <- Pagination.validate(params),
         {:ok, reviews} <-
           access_token
           |> Transport.request()
           |> Req.get(
             url: "/repos/#{repo}/pulls/#{pull_number}/reviews",
             params: Map.to_list(page)
           )
           |> Response.handle_pull_request_review_list_response() do
      {:ok, %{reviews: reviews, page: Pagination.metadata(page, length(reviews))}}
    end
  end

  def list_pull_request_requested_reviewers(repo, pull_number, access_token)
      when is_binary(repo) and is_integer(pull_number) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/repos/#{repo}/pulls/#{pull_number}/requested_reviewers")
    |> Response.handle_pull_request_requested_reviewer_response()
  end

  def list_check_runs(%{repo: repo, sha: sha} = params, access_token)
      when is_binary(repo) and is_binary(sha) and is_binary(access_token) do
    with {:ok, page} <- Pagination.validate(params),
         {:ok, result} <-
           access_token
           |> Transport.request()
           |> Req.get(
             url: "/repos/#{repo}/commits/#{sha}/check-runs",
             params: Map.to_list(page)
           )
           |> Response.handle_check_run_list_response() do
      {:ok,
       Map.put(
         result,
         :page,
         Pagination.metadata(page, length(result.check_runs), result.total_count)
       )}
    end
  end
end
