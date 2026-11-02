defmodule Jido.Connect.Gmail.ScopeResolver do
  @moduledoc """
  Resolves Gmail scopes.

  Metadata reads other than `google.gmail.labels.list` require
  `gmail.metadata` only when the connection holds no broader grant. When it
  holds `gmail.modify`, `gmail.readonly` or `https://mail.google.com/`, the
  first of them in that order is required, so a lease narrowed to
  `gmail.metadata` fails with missing scopes. The label list keeps
  `gmail.metadata` whenever it is granted.

  `google.gmail.messages.list` and `google.gmail.threads.list` also read the
  action input. Gmail rejects the `q` parameter under `gmail.metadata`, so a
  list with a non-empty `query` resolves like a content read: to
  `gmail.modify`, `gmail.readonly` or `https://mail.google.com/` when one of
  them is granted, otherwise to `gmail.readonly`. The rule follows what the
  client sends as `q`. The client drops only a `nil` or empty query, so a
  query of whitespace counts as a search. Without a query, or with a `nil` or
  empty one, both list actions keep the metadata-read resolution.
  """

  alias Jido.Connect.Data

  @metadata_scope "https://www.googleapis.com/auth/gmail.metadata"
  @readonly_scope "https://www.googleapis.com/auth/gmail.readonly"
  @send_scope "https://www.googleapis.com/auth/gmail.send"
  @compose_scope "https://www.googleapis.com/auth/gmail.compose"
  @labels_scope "https://www.googleapis.com/auth/gmail.labels"
  @modify_scope "https://www.googleapis.com/auth/gmail.modify"
  @mail_scope "https://mail.google.com/"
  @send_actions ["google.gmail.message.send"]
  @draft_read_actions [
    "google.gmail.drafts.list",
    "google.gmail.draft.get"
  ]
  @compose_actions [
    "google.gmail.draft.create",
    "google.gmail.draft.update",
    "google.gmail.draft.send",
    "google.gmail.draft.delete"
  ]
  @label_list_actions ["google.gmail.labels.list"]
  @label_read_actions ["google.gmail.label.get"]
  @label_crud_actions [
    "google.gmail.label.create",
    "google.gmail.label.update",
    "google.gmail.label.delete"
  ]
  @content_read_actions [
    "google.gmail.message.attachment.get",
    "google.gmail.message.content.get",
    "google.gmail.thread.content.get",
    "google.gmail.message.attachment.content.get"
  ]
  @search_list_actions [
    "google.gmail.messages.list",
    "google.gmail.threads.list"
  ]
  @modify_actions [
    "google.gmail.message.labels.apply",
    "google.gmail.messages.batch_modify",
    "google.gmail.message.trash",
    "google.gmail.message.untrash",
    "google.gmail.thread.modify",
    "google.gmail.thread.trash",
    "google.gmail.thread.untrash"
  ]
  @mail_actions [
    "google.gmail.message.delete",
    "google.gmail.messages.batch_delete",
    "google.gmail.thread.delete"
  ]

  def required_scopes(operation, input, connection) do
    operation_id = operation_id(operation)

    if operation_id in @search_list_actions and query_search?(input) do
      content_read_scopes(connection)
    else
      required_for_operation(operation_id, connection)
    end
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @send_actions and is_list(scopes) do
    cond do
      @send_scope in scopes -> [@send_scope]
      @compose_scope in scopes -> [@compose_scope]
      @modify_scope in scopes -> [@modify_scope]
      @mail_scope in scopes -> [@mail_scope]
      true -> [@send_scope]
    end
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @compose_actions and is_list(scopes) do
    cond do
      @compose_scope in scopes -> [@compose_scope]
      @modify_scope in scopes -> [@modify_scope]
      @mail_scope in scopes -> [@mail_scope]
      true -> [@compose_scope]
    end
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @draft_read_actions and is_list(scopes) do
    cond do
      @compose_scope in scopes -> [@compose_scope]
      @modify_scope in scopes -> [@modify_scope]
      @readonly_scope in scopes -> [@readonly_scope]
      @mail_scope in scopes -> [@mail_scope]
      true -> [@compose_scope]
    end
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @label_crud_actions and is_list(scopes) do
    cond do
      @labels_scope in scopes -> [@labels_scope]
      @modify_scope in scopes -> [@modify_scope]
      @mail_scope in scopes -> [@mail_scope]
      true -> [@labels_scope]
    end
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @label_list_actions and is_list(scopes) do
    cond do
      @metadata_scope in scopes -> [@metadata_scope]
      @labels_scope in scopes -> [@labels_scope]
      @modify_scope in scopes -> [@modify_scope]
      @readonly_scope in scopes -> [@readonly_scope]
      @mail_scope in scopes -> [@mail_scope]
      true -> [@metadata_scope]
    end
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @label_read_actions and is_list(scopes) do
    cond do
      @modify_scope in scopes -> [@modify_scope]
      @readonly_scope in scopes -> [@readonly_scope]
      @mail_scope in scopes -> [@mail_scope]
      true -> [@readonly_scope]
    end
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @modify_actions and is_list(scopes) do
    cond do
      @modify_scope in scopes -> [@modify_scope]
      @mail_scope in scopes -> [@mail_scope]
      true -> [@modify_scope]
    end
  end

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @mail_actions and is_list(scopes) do
    cond do
      @mail_scope in scopes -> [@mail_scope]
      true -> [@mail_scope]
    end
  end

  defp required_for_operation(operation_id, _connection) when operation_id in @send_actions,
    do: [@send_scope]

  defp required_for_operation(operation_id, _connection) when operation_id in @compose_actions,
    do: [@compose_scope]

  defp required_for_operation(operation_id, _connection) when operation_id in @draft_read_actions,
    do: [@compose_scope]

  defp required_for_operation(operation_id, _connection) when operation_id in @label_list_actions,
    do: [@metadata_scope]

  defp required_for_operation(operation_id, _connection) when operation_id in @label_read_actions,
    do: [@readonly_scope]

  defp required_for_operation(operation_id, _connection) when operation_id in @label_crud_actions,
    do: [@labels_scope]

  defp required_for_operation(operation_id, _connection) when operation_id in @modify_actions,
    do: [@modify_scope]

  defp required_for_operation(operation_id, _connection) when operation_id in @mail_actions,
    do: [@mail_scope]

  defp required_for_operation(operation_id, connection)
       when operation_id in @content_read_actions,
       do: content_read_scopes(connection)

  defp required_for_operation(_operation_id, %{scopes: scopes}) when is_list(scopes) do
    cond do
      @modify_scope in scopes -> [@modify_scope]
      @readonly_scope in scopes -> [@readonly_scope]
      @mail_scope in scopes -> [@mail_scope]
      true -> [@metadata_scope]
    end
  end

  defp required_for_operation(_operation_id, _connection), do: [@metadata_scope]

  defp content_read_scopes(%{scopes: scopes}) when is_list(scopes) do
    cond do
      @modify_scope in scopes -> [@modify_scope]
      @readonly_scope in scopes -> [@readonly_scope]
      @mail_scope in scopes -> [@mail_scope]
      true -> [@readonly_scope]
    end
  end

  defp content_read_scopes(_connection), do: [@readonly_scope]

  defp query_search?(input) do
    case Data.get(input, :query) do
      query when is_binary(query) -> query != ""
      _no_query -> false
    end
  end

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(_operation), do: nil
end
