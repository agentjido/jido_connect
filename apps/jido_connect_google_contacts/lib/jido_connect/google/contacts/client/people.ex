defmodule Jido.Connect.Google.Contacts.Client.People do
  @moduledoc "Google People API boundary for person reads and search."

  alias Jido.Connect.Google.Contacts.Client.{Params, Response, Transport}

  def list_people(%{resource_name: resource_name} = params, access_token)
      when is_binary(resource_name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v1/#{resource_path(resource_name)}/connections",
      params: Params.list_people_params(params)
    )
    |> Response.handle_person_list_response()
  end

  def get_person(%{resource_name: resource_name} = params, access_token)
      when is_binary(resource_name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v1/#{resource_path(resource_name)}",
      params: Params.get_person_params(params)
    )
    |> Response.handle_person_response()
  end

  def batch_get_people(%{resource_names: resource_names} = params, access_token)
      when is_list(resource_names) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v1/people:batchGet",
      params: Params.batch_get_people_params(params)
    )
    |> Response.handle_person_batch_get_response()
  end

  def search_people(%{query: query} = params, access_token)
      when is_binary(query) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v1/people:searchContacts",
      params: Params.search_people_params(params)
    )
    |> Response.handle_person_search_response()
  end

  def list_directory_people(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v1/people:listDirectoryPeople",
      params: Params.list_directory_people_params(params)
    )
    |> Response.handle_directory_people_list_response()
  end

  def search_directory_people(%{query: query} = params, access_token)
      when is_binary(query) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v1/people:searchDirectoryPeople",
      params: Params.search_directory_people_params(params)
    )
    |> Response.handle_directory_people_search_response()
  end

  def create_contact(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v1/people:createContact",
      params: Params.create_contact_params(params),
      json: Params.contact_body(params)
    )
    |> Response.handle_person_response()
  end

  def batch_create_contacts(%{contacts: contacts} = params, access_token)
      when is_list(contacts) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v1/people:batchCreateContacts",
      json: Params.batch_create_contacts_body(params)
    )
    |> Response.handle_person_batch_create_response()
  end

  def update_contact(%{resource_name: resource_name} = params, access_token)
      when is_binary(resource_name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.patch(
      url: "/v1/#{resource_path(resource_name)}:updateContact",
      params: Params.update_contact_params(params),
      json: Params.contact_body(params)
    )
    |> Response.handle_person_response()
  end

  def batch_update_contacts(%{contacts: contacts} = params, access_token)
      when is_list(contacts) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v1/people:batchUpdateContacts",
      json: Params.batch_update_contacts_body(params)
    )
    |> Response.handle_person_batch_update_response()
  end

  def delete_contact(%{resource_name: resource_name} = params, access_token)
      when is_binary(resource_name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.delete(url: "/v1/#{resource_path(resource_name)}:deleteContact")
    |> Response.handle_contact_delete_response(params)
  end

  def batch_delete_contacts(%{resource_names: resource_names} = params, access_token)
      when is_list(resource_names) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v1/people:batchDeleteContacts",
      json: Params.batch_delete_contacts_body(params)
    )
    |> Response.handle_person_batch_delete_response(params)
  end

  defp resource_path(resource_name) do
    resource_name
    |> String.split("/")
    |> Enum.map(fn segment -> URI.encode(segment, &URI.char_unreserved?/1) end)
    |> Enum.join("/")
  end
end
