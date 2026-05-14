defmodule Jido.Connect.Google.Drive.Client.Revisions do
  @moduledoc "Google Drive revisions API boundary."

  alias Jido.Connect.Google.Drive.Client.{Params, Response, Transport}

  def list_revisions(%{file_id: file_id} = params, access_token)
      when is_binary(file_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v3/files/#{encode_id(file_id)}/revisions",
      params: Params.list_revisions_params(params)
    )
    |> Response.handle_revision_list_response()
  end

  def get_revision(%{file_id: file_id, revision_id: revision_id} = params, access_token)
      when is_binary(file_id) and is_binary(revision_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v3/files/#{encode_id(file_id)}/revisions/#{encode_id(revision_id)}",
      params: Params.get_revision_params(params)
    )
    |> Response.handle_revision_response()
  end

  def update_revision(%{file_id: file_id, revision_id: revision_id} = params, access_token)
      when is_binary(file_id) and is_binary(revision_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.patch(
      url: "/v3/files/#{encode_id(file_id)}/revisions/#{encode_id(revision_id)}",
      params: Params.update_revision_params(params),
      json: Params.revision_body(params)
    )
    |> Response.handle_revision_response()
  end

  def delete_revision(%{file_id: file_id, revision_id: revision_id} = params, access_token)
      when is_binary(file_id) and is_binary(revision_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.delete(url: "/v3/files/#{encode_id(file_id)}/revisions/#{encode_id(revision_id)}")
    |> Response.handle_revision_delete_response(params)
  end

  defp encode_id(id), do: URI.encode(id, &URI.char_unreserved?/1)
end
