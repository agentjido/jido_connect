defmodule Jido.Connect.Gmail.ScopeResolver do
  @moduledoc """
  Resolves Gmail scopes.

  Metadata reads prefer `gmail.metadata`, while accepting broader read or
  modify grants that hosts may already have.
  """

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
    "google.gmail.message.attachment.get"
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

  def required_scopes(operation, _input, connection) do
    operation
    |> operation_id()
    |> required_for_operation(connection)
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

  defp required_for_operation(operation_id, %{scopes: scopes})
       when operation_id in @content_read_actions and is_list(scopes) do
    cond do
      @modify_scope in scopes -> [@modify_scope]
      @readonly_scope in scopes -> [@readonly_scope]
      @mail_scope in scopes -> [@mail_scope]
      true -> [@readonly_scope]
    end
  end

  defp required_for_operation(operation_id, _connection)
       when operation_id in @content_read_actions,
       do: [@readonly_scope]

  defp required_for_operation(_operation_id, %{scopes: scopes}) when is_list(scopes) do
    cond do
      @modify_scope in scopes -> [@modify_scope]
      @readonly_scope in scopes -> [@readonly_scope]
      @mail_scope in scopes -> [@mail_scope]
      true -> [@metadata_scope]
    end
  end

  defp required_for_operation(_operation_id, _connection), do: [@metadata_scope]

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(operation), do: Map.get(operation, :id)
end
