defmodule Jido.Connect.Google.Drive.Client.Comments do
  @moduledoc "Google Drive comments API boundary."

  alias Jido.Connect.Google.Drive.Client.{Params, Response, Transport}

  def list_comments(%{file_id: file_id} = params, access_token)
      when is_binary(file_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v3/files/#{encode_id(file_id)}/comments",
      params: Params.list_comments_params(params)
    )
    |> Response.handle_comment_list_response()
  end

  def get_comment(%{file_id: file_id, comment_id: comment_id} = params, access_token)
      when is_binary(file_id) and is_binary(comment_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v3/files/#{encode_id(file_id)}/comments/#{encode_id(comment_id)}",
      params: Params.get_comment_params(params)
    )
    |> Response.handle_comment_response()
  end

  def create_comment(%{file_id: file_id} = params, access_token)
      when is_binary(file_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v3/files/#{encode_id(file_id)}/comments",
      params: Params.comment_mutation_params(params),
      json: Params.comment_body(params)
    )
    |> Response.handle_comment_response()
  end

  def update_comment(%{file_id: file_id, comment_id: comment_id} = params, access_token)
      when is_binary(file_id) and is_binary(comment_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.patch(
      url: "/v3/files/#{encode_id(file_id)}/comments/#{encode_id(comment_id)}",
      params: Params.comment_mutation_params(params),
      json: Params.comment_body(params)
    )
    |> Response.handle_comment_response()
  end

  def delete_comment(%{file_id: file_id, comment_id: comment_id} = params, access_token)
      when is_binary(file_id) and is_binary(comment_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.delete(url: "/v3/files/#{encode_id(file_id)}/comments/#{encode_id(comment_id)}")
    |> Response.handle_comment_delete_response(params)
  end

  defp encode_id(id), do: URI.encode(id, &URI.char_unreserved?/1)
end
