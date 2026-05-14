defmodule Jido.Connect.Gmail.Client.Users do
  @moduledoc "Gmail users API boundary."

  alias Jido.Connect.Gmail.Client.{Params, Response, Transport}

  def get_profile(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/gmail/v1/users/me/profile")
    |> Response.handle_profile_response()
  end

  def list_labels(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/gmail/v1/users/me/labels")
    |> Response.handle_label_list_response()
  end

  def get_label(%{label_id: label_id}, access_token)
      when is_binary(label_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/gmail/v1/users/me/labels/#{encode_path_segment(label_id)}")
    |> Response.handle_label_response()
  end

  def list_messages(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/gmail/v1/users/me/messages", params: Params.message_list_params(params))
    |> Response.handle_message_list_response()
  end

  def get_message(%{message_id: message_id} = params, access_token)
      when is_binary(message_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/gmail/v1/users/me/messages/#{encode_path_segment(message_id)}",
      params: Params.metadata_get_params(params)
    )
    |> Response.handle_message_response()
  end

  def list_threads(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/gmail/v1/users/me/threads", params: Params.thread_list_params(params))
    |> Response.handle_thread_list_response()
  end

  def get_thread(%{thread_id: thread_id} = params, access_token)
      when is_binary(thread_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/gmail/v1/users/me/threads/#{encode_path_segment(thread_id)}",
      params: Params.metadata_get_params(params)
    )
    |> Response.handle_thread_response()
  end

  def list_drafts(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/gmail/v1/users/me/drafts", params: Params.draft_list_params(params))
    |> Response.handle_draft_list_response()
  end

  def get_draft(%{draft_id: draft_id} = params, access_token)
      when is_binary(draft_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/gmail/v1/users/me/drafts/#{encode_path_segment(draft_id)}",
      params: Params.metadata_get_params(params)
    )
    |> Response.handle_draft_response()
  end

  def list_history(%{start_history_id: start_history_id} = params, access_token)
      when is_binary(start_history_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/gmail/v1/users/me/history", params: Params.history_list_params(params))
    |> Response.handle_history_list_response()
  end

  def get_attachment(%{message_id: message_id, attachment_id: attachment_id}, access_token)
      when is_binary(message_id) and is_binary(attachment_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url:
        "/gmail/v1/users/me/messages/#{encode_path_segment(message_id)}/attachments/#{encode_path_segment(attachment_id)}"
    )
    |> Response.handle_attachment_response()
  end

  def start_watch(%{topic_name: topic_name} = params, access_token)
      when is_binary(topic_name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/gmail/v1/users/me/watch", json: Params.watch_body(params))
    |> Response.handle_watch_response()
  end

  def stop_watch(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/gmail/v1/users/me/stop", json: %{})
    |> Response.handle_stop_watch_response()
  end

  def send_message(%{raw: raw} = params, access_token)
      when is_binary(raw) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/gmail/v1/users/me/messages/send",
      json: Params.send_message_body(params)
    )
    |> Response.handle_message_response()
  end

  def create_draft(%{raw: raw} = params, access_token)
      when is_binary(raw) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/gmail/v1/users/me/drafts",
      json: Params.create_draft_body(params)
    )
    |> Response.handle_draft_response()
  end

  def update_draft(%{draft_id: draft_id, raw: raw} = params, access_token)
      when is_binary(draft_id) and is_binary(raw) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.put(
      url: "/gmail/v1/users/me/drafts/#{encode_path_segment(draft_id)}",
      json: Params.update_draft_body(params)
    )
    |> Response.handle_draft_response()
  end

  def send_draft(%{draft_id: draft_id} = params, access_token)
      when is_binary(draft_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/gmail/v1/users/me/drafts/send",
      json: Params.send_draft_body(params)
    )
    |> Response.handle_message_response()
  end

  def delete_draft(%{draft_id: draft_id}, access_token)
      when is_binary(draft_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.delete(url: "/gmail/v1/users/me/drafts/#{encode_path_segment(draft_id)}")
    |> Response.handle_empty_response(%{deleted?: true, draft_id: draft_id})
  end

  def create_label(%{name: name} = params, access_token)
      when is_binary(name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/gmail/v1/users/me/labels",
      json: Params.label_body(params)
    )
    |> Response.handle_label_response()
  end

  def update_label(%{label_id: label_id} = params, access_token)
      when is_binary(label_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.put(
      url: "/gmail/v1/users/me/labels/#{encode_path_segment(label_id)}",
      json: Params.label_body(params)
    )
    |> Response.handle_label_response()
  end

  def delete_label(%{label_id: label_id}, access_token)
      when is_binary(label_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.delete(url: "/gmail/v1/users/me/labels/#{encode_path_segment(label_id)}")
    |> Response.handle_empty_response(%{deleted?: true, label_id: label_id})
  end

  def apply_message_labels(%{message_id: message_id} = params, access_token)
      when is_binary(message_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/gmail/v1/users/me/messages/#{encode_path_segment(message_id)}/modify",
      json: Params.modify_labels_body(params)
    )
    |> Response.handle_message_response()
  end

  def batch_modify_messages(%{message_ids: message_ids} = params, access_token)
      when is_list(message_ids) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/gmail/v1/users/me/messages/batchModify",
      json: Params.batch_modify_messages_body(params)
    )
    |> Response.handle_empty_response(%{
      modified?: true,
      message_ids: message_ids,
      add_label_ids: Map.get(params, :add_label_ids, []),
      remove_label_ids: Map.get(params, :remove_label_ids, [])
    })
  end

  def trash_message(%{message_id: message_id}, access_token)
      when is_binary(message_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/gmail/v1/users/me/messages/#{encode_path_segment(message_id)}/trash")
    |> Response.handle_message_response()
  end

  def untrash_message(%{message_id: message_id}, access_token)
      when is_binary(message_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/gmail/v1/users/me/messages/#{encode_path_segment(message_id)}/untrash")
    |> Response.handle_message_response()
  end

  def delete_message(%{message_id: message_id}, access_token)
      when is_binary(message_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.delete(url: "/gmail/v1/users/me/messages/#{encode_path_segment(message_id)}")
    |> Response.handle_empty_response(%{deleted?: true, message_id: message_id})
  end

  def batch_delete_messages(%{message_ids: message_ids} = params, access_token)
      when is_list(message_ids) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/gmail/v1/users/me/messages/batchDelete",
      json: Params.batch_delete_messages_body(params)
    )
    |> Response.handle_empty_response(%{deleted?: true, message_ids: message_ids})
  end

  def modify_thread(%{thread_id: thread_id} = params, access_token)
      when is_binary(thread_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/gmail/v1/users/me/threads/#{encode_path_segment(thread_id)}/modify",
      json: Params.modify_labels_body(params)
    )
    |> Response.handle_thread_response()
  end

  def trash_thread(%{thread_id: thread_id}, access_token)
      when is_binary(thread_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/gmail/v1/users/me/threads/#{encode_path_segment(thread_id)}/trash")
    |> Response.handle_thread_response()
  end

  def untrash_thread(%{thread_id: thread_id}, access_token)
      when is_binary(thread_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(url: "/gmail/v1/users/me/threads/#{encode_path_segment(thread_id)}/untrash")
    |> Response.handle_thread_response()
  end

  def delete_thread(%{thread_id: thread_id}, access_token)
      when is_binary(thread_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.delete(url: "/gmail/v1/users/me/threads/#{encode_path_segment(thread_id)}")
    |> Response.handle_empty_response(%{deleted?: true, thread_id: thread_id})
  end

  defp encode_path_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)
end
