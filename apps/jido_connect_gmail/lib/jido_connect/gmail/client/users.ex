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

  defp encode_path_segment(value), do: URI.encode(value, &URI.char_unreserved?/1)
end
