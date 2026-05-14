defmodule Jido.Connect.Google.Drive.Client.Replies do
  @moduledoc "Google Drive replies API boundary."

  alias Jido.Connect.Google.Drive.Client.{Params, Response, Transport}

  def list_replies(%{file_id: file_id, comment_id: comment_id} = params, access_token)
      when is_binary(file_id) and is_binary(comment_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v3/files/#{encode_id(file_id)}/comments/#{encode_id(comment_id)}/replies",
      params: Params.list_replies_params(params)
    )
    |> Response.handle_reply_list_response()
  end

  def get_reply(
        %{file_id: file_id, comment_id: comment_id, reply_id: reply_id} = params,
        access_token
      )
      when is_binary(file_id) and is_binary(comment_id) and is_binary(reply_id) and
             is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url:
        "/v3/files/#{encode_id(file_id)}/comments/#{encode_id(comment_id)}/replies/#{encode_id(reply_id)}",
      params: Params.get_reply_params(params)
    )
    |> Response.handle_reply_response()
  end

  def create_reply(%{file_id: file_id, comment_id: comment_id} = params, access_token)
      when is_binary(file_id) and is_binary(comment_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v3/files/#{encode_id(file_id)}/comments/#{encode_id(comment_id)}/replies",
      params: Params.reply_mutation_params(params),
      json: Params.reply_body(params)
    )
    |> Response.handle_reply_response()
  end

  def update_reply(
        %{file_id: file_id, comment_id: comment_id, reply_id: reply_id} = params,
        access_token
      )
      when is_binary(file_id) and is_binary(comment_id) and is_binary(reply_id) and
             is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.patch(
      url:
        "/v3/files/#{encode_id(file_id)}/comments/#{encode_id(comment_id)}/replies/#{encode_id(reply_id)}",
      params: Params.reply_mutation_params(params),
      json: Params.reply_body(params)
    )
    |> Response.handle_reply_response()
  end

  def delete_reply(
        %{file_id: file_id, comment_id: comment_id, reply_id: reply_id} = params,
        access_token
      )
      when is_binary(file_id) and is_binary(comment_id) and is_binary(reply_id) and
             is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.delete(
      url:
        "/v3/files/#{encode_id(file_id)}/comments/#{encode_id(comment_id)}/replies/#{encode_id(reply_id)}"
    )
    |> Response.handle_reply_delete_response(params)
  end

  defp encode_id(id), do: URI.encode(id, &URI.char_unreserved?/1)
end
