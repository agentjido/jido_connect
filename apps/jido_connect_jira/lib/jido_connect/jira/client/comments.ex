defmodule Jido.Connect.Jira.Client.Comments do
  @moduledoc """
  Jira issue comment reads, `GET /rest/api/3/issue/{issueIdOrKey}/comment`.

  `list/3` requests one page of an issue's comments, oldest first
  (`orderBy=created`), without rendered HTML. Jira answers with `startAt`,
  `maxResults`, `total` and `comments`, but without a last-page flag, so the
  page end comes from `total`:

    * `is_last` is `true` when `startAt` plus the number of comments reaches
      `total`. A page with fewer comments than `maxResults` stays non-final
      until then.
    * `next_start_at` is `startAt` plus the number of comments. On the last
      page it is `nil`, and the output of `jira.issue.comment.list` leaves it
      out, so a caller that follows it cannot loop on an empty page.

  A page fails with an `:invalid_response` error whose details name the
  offending key, without comment content, when `comments` is not a list,
  `startAt`, `maxResults` or `total` is not a non-negative integer, a comment
  does not normalize, or the page is empty although it is not the last. A
  comment body that is not valid ADF fails the page with `field: "body"`, the
  comment ID and the projection reason, as malformed descriptions fail issue
  reads.

  Page size and offset are connector choices: `max_results` defaults to 50
  and must be 1 to 100, `start_at` defaults to 0 and must not be negative.
  Other values fail with a `Jido.Connect.Error.ValidationError` before a
  request is sent; Jira itself would turn 0 into 1, cap larger values at 100
  and read a negative offset as 0.
  """

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Jira.Client.{Normalizer, Request, Transport}
  alias Jido.Connect.Jira.CommentPage

  @default_max_results 50
  @min_max_results 1
  @max_max_results 100
  @invalid "Jira comment list response was invalid"

  @doc """
  Requests one page of comments of the issue `issue_key`, a key such as
  `PROJ-123` or a numeric issue ID.

  Options are `:start_at` (default 0) and `:max_results` (default 50, 1 to
  100). Returns a plain map with the fields of `Jido.Connect.Jira.CommentPage`;
  each comment is a map from `Normalizer.comment_map/1`.
  """
  @spec list(String.t(), Request.t(), keyword()) :: {:ok, map()} | {:error, Error.error()}
  def list(issue_key, %Request{} = request, opts \\ []) when is_binary(issue_key) do
    start_at = Keyword.get(opts, :start_at, 0)
    max_results = Keyword.get(opts, :max_results, @default_max_results)

    with :ok <- check_start_at(start_at),
         :ok <- check_max_results(max_results),
         {:ok, segment} <- Request.issue_segment(issue_key) do
      request
      |> Transport.request()
      |> Req.get(
        url: Request.url(request, "/rest/api/3/issue/#{segment}/comment"),
        params: [startAt: start_at, maxResults: max_results, orderBy: "created"]
      )
      |> handle_response(issue_key)
    end
  end

  defp check_start_at(start_at) when is_integer(start_at) and start_at >= 0, do: :ok

  defp check_start_at(start_at) do
    {:error,
     Error.validation("Jira comment list start_at must be a non-negative integer",
       reason: :invalid_start_at,
       subject: :start_at,
       details: %{start_at: start_at, minimum: 0}
     )}
  end

  defp check_max_results(max_results)
       when is_integer(max_results) and max_results in @min_max_results..@max_max_results,
       do: :ok

  defp check_max_results(max_results) do
    {:error,
     Error.validation("Jira comment list max_results must be an integer from 1 to 100",
       reason: :invalid_max_results,
       subject: :max_results,
       details: %{max_results: max_results, minimum: @min_max_results, maximum: @max_max_results}
     )}
  end

  defp handle_response({:ok, %{status: status, body: body}}, issue_key)
       when status in 200..299 and is_map(body) do
    with {:ok, envelope} <- envelope(body),
         {:ok, comments} <- comments(envelope.comments, body),
         {:ok, page} <- page(issue_key, envelope, comments, body) do
      {:ok, page_map(page)}
    end
  end

  defp handle_response({:ok, %{status: status, body: body}}, _issue_key)
       when status in 200..299 do
    Transport.invalid_success_response(@invalid, body)
  end

  defp handle_response(response, _issue_key) do
    Transport.handle_error_response(response, message: "Jira comment list request failed")
  end

  # Checks the page envelope before any comment is read.
  defp envelope(body) do
    envelope = %{
      comments: Data.get(body, "comments"),
      start_at: Data.get(body, "startAt"),
      max_results: Data.get(body, "maxResults"),
      total: Data.get(body, "total")
    }

    cond do
      not is_list(envelope.comments) -> invalid(body, "comments")
      not count?(envelope.start_at) -> invalid(body, "startAt")
      not count?(envelope.max_results) -> invalid(body, "maxResults")
      not count?(envelope.total) -> invalid(body, "total")
      true -> {:ok, envelope}
    end
  end

  defp count?(value), do: is_integer(value) and value >= 0

  defp comments(payloads, body) do
    payloads
    |> Enum.reduce_while({:ok, []}, fn payload, {:ok, comments} ->
      case Normalizer.comment(payload) do
        {:ok, comment} ->
          {:cont, {:ok, [comment | comments]}}

        {:error, %Error.ValidationError{subject: :adf, reason: reason}} ->
          {:halt, invalid_body(payload, reason)}

        {:error, _invalid} ->
          {:halt, invalid(body, "comments")}
      end
    end)
    |> case do
      {:ok, comments} -> {:ok, Enum.reverse(comments)}
      {:error, _error} = error -> error
    end
  end

  # An empty page before the end would repeat its own offset forever.
  defp page(_issue_key, %{comments: [], start_at: start_at, total: total}, _comments, body)
       when start_at < total,
       do: invalid(body, "comments")

  defp page(issue_key, envelope, comments, _body) do
    next_start_at = envelope.start_at + length(comments)
    is_last = next_start_at >= envelope.total

    {:ok,
     CommentPage.new!(%{
       issue: issue_key,
       comments: comments,
       start_at: envelope.start_at,
       max_results: envelope.max_results,
       total: envelope.total,
       is_last: is_last,
       next_start_at: if(is_last, do: nil, else: next_start_at)
     })}
  end

  defp page_map(%CommentPage{} = page) do
    page
    |> Map.from_struct()
    |> Map.drop([:metadata])
    |> Map.update!(:comments, fn comments -> Enum.map(comments, &Normalizer.comment_map/1) end)
  end

  # `Error.provider/2` keeps only a value-free summary of `body`.
  defp invalid(body, field) do
    {:error,
     Error.provider(@invalid,
       provider: :jira,
       reason: :invalid_response,
       delivery: :response_received,
       details: %{field: field, body: body}
     )}
  end

  defp invalid_body(payload, reason) do
    {:error,
     Error.provider(@invalid,
       provider: :jira,
       reason: :invalid_response,
       delivery: :response_received,
       details: %{field: "body", comment_id: Data.get(payload, "id"), adf_reason: reason}
     )}
  end
end
