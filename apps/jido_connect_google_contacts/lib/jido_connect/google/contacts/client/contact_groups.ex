defmodule Jido.Connect.Google.Contacts.Client.ContactGroups do
  @moduledoc "Google People API boundary for contact group reads and mutations."

  alias Jido.Connect.Google.Contacts.Client.{Params, Response, Transport}

  def list_contact_groups(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v1/contactGroups",
      params: Params.list_contact_groups_params(params)
    )
    |> Response.handle_contact_group_list_response()
  end

  def get_contact_group(%{resource_name: resource_name} = params, access_token)
      when is_binary(resource_name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v1/#{resource_path(resource_name)}",
      params: Params.get_contact_group_params(params)
    )
    |> Response.handle_contact_group_response()
  end

  def batch_get_contact_groups(%{resource_names: resource_names} = params, access_token)
      when is_list(resource_names) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v1/contactGroups:batchGet",
      params: Params.batch_get_contact_groups_params(params)
    )
    |> Response.handle_contact_group_batch_get_response()
  end

  def create_contact_group(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v1/contactGroups",
      params: Params.create_contact_group_params(params),
      json: Params.contact_group_body(params)
    )
    |> Response.handle_contact_group_response()
  end

  def update_contact_group(%{resource_name: resource_name} = params, access_token)
      when is_binary(resource_name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.put(
      url: "/v1/#{resource_path(resource_name)}",
      params: Params.update_contact_group_params(params),
      json: Params.contact_group_body(params)
    )
    |> Response.handle_contact_group_response()
  end

  def delete_contact_group(%{resource_name: resource_name} = params, access_token)
      when is_binary(resource_name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.delete(
      url: "/v1/#{resource_path(resource_name)}",
      params: Params.delete_contact_group_params(params)
    )
    |> Response.handle_contact_group_delete_response(params)
  end

  def modify_contact_group_members(%{resource_name: resource_name} = params, access_token)
      when is_binary(resource_name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v1/#{resource_path(resource_name)}/members:modify",
      json: Params.modify_contact_group_members_body(params)
    )
    |> Response.handle_contact_group_members_modify_response(params)
  end

  defp resource_path(resource_name) do
    resource_name
    |> String.split("/")
    |> Enum.map(fn segment -> URI.encode(segment, &URI.char_unreserved?/1) end)
    |> Enum.join("/")
  end
end
