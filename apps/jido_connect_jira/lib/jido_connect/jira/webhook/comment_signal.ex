defmodule Jido.Connect.Jira.Webhook.CommentSignal do
  @moduledoc """
  Normalizes `comment_created` and `comment_updated` deliveries into
  `jira.comment.changed` signals.

  Comment deliveries carry no top-level `user`. The acting user is
  `comment.author` for `comment_created` and `comment.updateAuthor` for
  `comment_updated`; `actor_id` and `actor_name` are absent when that object
  is missing. `comment_author_id` and `comment_author_name` always name the
  author who created the comment.

  `comment_body` comes from `Jido.Connect.Jira.ADFText`: an ADF body is
  rendered with the shared projection in `:degrade` mode and
  `comment_body_unsupported_nodes` lists the skipped node and mark types; a
  plain-string body, as administrator webhooks send it, passes through with
  an empty list. A body that projects to `""` keeps `comment_body: ""`, so an
  empty comment stays apart from a delivery without a body, which has neither
  body field; `Jido.Connect.Jira.Comment` follows the same rule. A body that
  is not valid ADF fails with `:invalid_webhook_event`.

  A missing `comment` or `issue`, a missing comment or issue `id`, and an
  `author` or `updateAuthor` that is neither an object nor `null` fail with
  `:invalid_webhook_event`. `matched_webhook_ids` and `timestamp` follow
  `Jido.Connect.Jira.Webhook.Payload`.
  """

  alias Jido.Connect.{Data, Error}
  alias Jido.Connect.Jira.ADFText
  alias Jido.Connect.Jira.Webhook.Payload

  @doc "Normalizes a comment delivery of `event_type`."
  @spec normalize(String.t(), map()) :: Payload.result(map())
  def normalize(event_type, payload) do
    with {:ok, comment} <- Payload.required_object(payload, "comment", event_type, "comment"),
         {:ok, comment_id} <- Payload.id(comment, event_type, "comment.id"),
         {:ok, issue} <- Payload.required_object(payload, "issue", event_type, "issue"),
         {:ok, issue_id} <- Payload.id(issue, event_type, "issue.id"),
         {:ok, author} <- Payload.object(comment, "author", event_type, "comment.author"),
         {:ok, update_author} <-
           Payload.object(comment, "updateAuthor", event_type, "comment.updateAuthor"),
         {:ok, body} <- body(comment, event_type),
         {:ok, matched_webhook_ids} <- Payload.matched_webhook_ids(payload, event_type),
         {:ok, timestamp} <- Payload.timestamp(payload, event_type) do
      actor = actor(event_type, author, update_author)

      signal =
        %{
          event_type: event_type,
          change_type: change_type(event_type),
          actor_id: Payload.dig(actor, ["accountId"]),
          actor_name: Payload.dig(actor, ["displayName"]),
          comment_id: comment_id,
          comment_created_at: Data.get(comment, "created"),
          comment_updated_at: Data.get(comment, "updated"),
          comment_author_id: Payload.dig(author, ["accountId"]),
          comment_author_name: Payload.dig(author, ["displayName"]),
          issue_id: issue_id,
          issue_key: Data.get(issue, "key"),
          matched_webhook_ids: matched_webhook_ids,
          timestamp: timestamp
        }
        |> Data.compact()

      {:ok, put_body(signal, body)}
    end
  end

  @doc "Returns the change type for a comment event type."
  @spec change_type(String.t()) :: String.t()
  def change_type("comment_created"), do: "created"
  def change_type("comment_updated"), do: "updated"
  def change_type(_event_type), do: "unknown"

  defp actor("comment_created", author, _update_author), do: author
  defp actor("comment_updated", _author, update_author), do: update_author

  defp body(comment, event_type) do
    case ADFText.project(Data.get(comment, "body")) do
      {:ok, body} ->
        {:ok, body}

      {:error, %Error.ValidationError{reason: reason}} ->
        {:error,
         Error.provider("Jira webhook comment body is invalid",
           provider: :jira,
           reason: :invalid_webhook_event,
           details: %{event_type: event_type, field: "comment.body", adf_reason: reason}
         )}
    end
  end

  # Added after `Data.compact/1`, which would drop the "" of an empty body.
  defp put_body(signal, nil), do: signal

  defp put_body(signal, body) do
    Map.merge(signal, %{
      comment_body: ADFText.text(body),
      comment_body_unsupported_nodes: ADFText.unsupported_nodes(body)
    })
  end
end
