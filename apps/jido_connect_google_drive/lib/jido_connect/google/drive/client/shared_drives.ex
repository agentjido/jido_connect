defmodule Jido.Connect.Google.Drive.Client.SharedDrives do
  @moduledoc "Google Drive shared drives API boundary."

  alias Jido.Connect.Google.Drive.Client.{Params, Response, Transport}

  def list_shared_drives(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/v3/drives", params: Params.list_shared_drives_params(params))
    |> Response.handle_shared_drive_list_response()
  end

  def get_shared_drive(%{shared_drive_id: shared_drive_id} = params, access_token)
      when is_binary(shared_drive_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v3/drives/#{encode_id(shared_drive_id)}",
      params: Params.get_shared_drive_params(params)
    )
    |> Response.handle_shared_drive_response()
  end

  def create_shared_drive(%{request_id: request_id, name: name} = params, access_token)
      when is_binary(request_id) and is_binary(name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v3/drives",
      params: Params.create_shared_drive_params(params),
      json: Params.shared_drive_body(params)
    )
    |> Response.handle_shared_drive_response()
  end

  def update_shared_drive(%{shared_drive_id: shared_drive_id} = params, access_token)
      when is_binary(shared_drive_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.patch(
      url: "/v3/drives/#{encode_id(shared_drive_id)}",
      params: Params.update_shared_drive_params(params),
      json: Params.shared_drive_body(params)
    )
    |> Response.handle_shared_drive_response()
  end

  def delete_shared_drive(%{shared_drive_id: shared_drive_id} = params, access_token)
      when is_binary(shared_drive_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.delete(
      url: "/v3/drives/#{encode_id(shared_drive_id)}",
      params: Params.delete_shared_drive_params(params)
    )
    |> Response.handle_shared_drive_delete_response(params)
  end

  def hide_shared_drive(%{shared_drive_id: shared_drive_id} = params, access_token)
      when is_binary(shared_drive_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v3/drives/#{encode_id(shared_drive_id)}/hide",
      params: Params.shared_drive_visibility_params(params)
    )
    |> Response.handle_shared_drive_response()
  end

  def unhide_shared_drive(%{shared_drive_id: shared_drive_id} = params, access_token)
      when is_binary(shared_drive_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v3/drives/#{encode_id(shared_drive_id)}/unhide",
      params: Params.shared_drive_visibility_params(params)
    )
    |> Response.handle_shared_drive_response()
  end

  defp encode_id(id), do: URI.encode(id, &URI.char_unreserved?/1)
end
