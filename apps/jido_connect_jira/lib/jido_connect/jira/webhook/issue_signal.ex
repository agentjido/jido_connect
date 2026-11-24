defmodule Jido.Connect.Jira.Webhook.IssueSignal do
  @moduledoc """
  Normalizes `jira:issue_created` and `jira:issue_updated` deliveries into
  `jira.issue.changed` signals.

  - `issue_event_type_name` passes Jira's value through unchanged. It names
    the Jira event that fired, which depends on the operation and on the
    workflow transition, so status, assignee and due-date changes are read
    from the changelog items. In one capture run on 2026-10-30, with a
    simplified workflow and fields changed by REST edits, a status change
    arrived as `issue_generic` and assignee and due-date changes as
    `issue_updated`. Other workflows and the assign operation can send other
    names, such as `issue_assigned`, `issue_resolved` or `issue_work_started`.
  - `actor_id` and `actor_name` come from the top-level `user`.
  - `assigned` is `true` when `fields.assignee` holds a user and `false` when
    Jira sends `"assignee": null`; it is absent when the fields leave the
    assignee out. `assignee_id` and `assignee_name` appear only for a user.
  - `changelog` follows `Jido.Connect.Jira.Webhook.Changelog`.
  - `matched_webhook_ids` and `timestamp` follow
    `Jido.Connect.Jira.Webhook.Payload`.

  A missing `issue` or issue `id`, and `fields`, `user` or `fields.assignee`
  values that are neither objects nor `null`, fail with
  `:invalid_webhook_event`.
  """

  alias Jido.Connect.Data
  alias Jido.Connect.Jira.Webhook.{Changelog, Payload}

  @doc "Normalizes an issue delivery of `event_type`."
  @spec normalize(String.t(), map()) :: Payload.result(map())
  def normalize(event_type, payload) do
    with {:ok, issue} <- Payload.required_object(payload, "issue", event_type, "issue"),
         {:ok, issue_id} <- Payload.id(issue, event_type, "issue.id"),
         {:ok, fields} <- Payload.object(issue, "fields", event_type, "issue.fields"),
         {:ok, user} <- Payload.object(payload, "user", event_type, "user"),
         {:ok, assignee} <- assignee(fields || %{}, event_type),
         {:ok, changelog} <- Changelog.normalize(payload, event_type),
         {:ok, matched_webhook_ids} <- Payload.matched_webhook_ids(payload, event_type),
         {:ok, timestamp} <- Payload.timestamp(payload, event_type) do
      fields = fields || %{}

      signal =
        %{
          event_type: event_type,
          change_type: change_type(event_type),
          issue_event_type_name: Data.get(payload, "issue_event_type_name"),
          actor_id: Payload.dig(user, ["accountId"]),
          actor_name: Payload.dig(user, ["displayName"]),
          issue_id: issue_id,
          issue_key: Data.get(issue, "key"),
          project_key: Payload.dig(fields, ["project", "key"]),
          project_name: Payload.dig(fields, ["project", "name"]),
          summary: Data.get(fields, "summary"),
          issue_type_name: Payload.dig(fields, ["issuetype", "name"]),
          status_name: Payload.dig(fields, ["status", "name"]),
          priority_name: Payload.dig(fields, ["priority", "name"]),
          labels: Data.get(fields, "labels", []),
          reporter_id: Payload.dig(fields, ["reporter", "accountId"]),
          reporter_name: Payload.dig(fields, ["reporter", "displayName"]),
          created_at: Data.get(fields, "created"),
          updated_at: Data.get(fields, "updated"),
          changelog: changelog,
          matched_webhook_ids: matched_webhook_ids,
          timestamp: timestamp
        }
        |> Data.compact()

      {:ok, Map.merge(signal, assignee)}
    end
  end

  @doc "Returns the change type for an issue event type."
  @spec change_type(String.t()) :: String.t()
  def change_type("jira:issue_created"), do: "created"
  def change_type("jira:issue_updated"), do: "updated"
  def change_type(_event_type), do: "unknown"

  defp assignee(fields, event_type) do
    case Map.fetch(fields, "assignee") do
      :error ->
        {:ok, %{}}

      {:ok, nil} ->
        {:ok, %{assigned: false}}

      {:ok, %{} = user} ->
        {:ok,
         Data.compact(%{
           assigned: true,
           assignee_id: Data.get(user, "accountId"),
           assignee_name: Data.get(user, "displayName")
         })}

      {:ok, _other} ->
        {:error, Payload.invalid(event_type, "issue.fields.assignee")}
    end
  end
end
