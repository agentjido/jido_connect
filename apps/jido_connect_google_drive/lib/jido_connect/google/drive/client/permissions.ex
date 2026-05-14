defmodule Jido.Connect.Google.Drive.Client.Permissions do
  @moduledoc "Google Drive permissions API boundary."

  alias Jido.Connect.Google.Drive.Client.{Params, Response, Transport}

  def list_permissions(%{file_id: file_id} = params, access_token)
      when is_binary(file_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v3/files/#{encode_id(file_id)}/permissions",
      params: Params.list_permissions_params(params)
    )
    |> Response.handle_permission_list_response()
  end

  def create_permission(%{file_id: file_id} = params, access_token)
      when is_binary(file_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v3/files/#{encode_id(file_id)}/permissions",
      params: Params.create_permission_params(params),
      json: Params.permission_body(params)
    )
    |> Response.handle_permission_response()
  end

  def get_permission(%{file_id: file_id, permission_id: permission_id} = params, access_token)
      when is_binary(file_id) and is_binary(permission_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v3/files/#{encode_id(file_id)}/permissions/#{encode_id(permission_id)}",
      params: Params.get_permission_params(params)
    )
    |> Response.handle_permission_response()
  end

  def update_permission(%{file_id: file_id, permission_id: permission_id} = params, access_token)
      when is_binary(file_id) and is_binary(permission_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.patch(
      url: "/v3/files/#{encode_id(file_id)}/permissions/#{encode_id(permission_id)}",
      params: Params.update_permission_params(params),
      json: Params.permission_update_body(params)
    )
    |> Response.handle_permission_response()
  end

  def delete_permission(%{file_id: file_id, permission_id: permission_id} = params, access_token)
      when is_binary(file_id) and is_binary(permission_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.delete(
      url: "/v3/files/#{encode_id(file_id)}/permissions/#{encode_id(permission_id)}",
      params: Params.delete_permission_params(params)
    )
    |> Response.handle_permission_delete_response(params)
  end

  defp encode_id(file_id), do: URI.encode(file_id, &URI.char_unreserved?/1)
end
