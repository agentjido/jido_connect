defmodule Jido.Connect.Google.Contacts.Client.OtherContacts do
  @moduledoc "Google People API boundary for otherContacts resources."

  alias Jido.Connect.Google.Contacts.Client.{Params, Response, Transport}

  def list_other_contacts(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v1/otherContacts",
      params: Params.list_other_contacts_params(params)
    )
    |> Response.handle_other_contacts_list_response()
  end

  def search_other_contacts(%{query: query} = params, access_token)
      when is_binary(query) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v1/otherContacts:search",
      params: Params.search_other_contacts_params(params)
    )
    |> Response.handle_person_search_response()
  end

  def copy_other_contact(%{resource_name: resource_name} = params, access_token)
      when is_binary(resource_name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.post(
      url: "/v1/#{resource_path(resource_name)}:copyOtherContactToMyContactsGroup",
      json: Params.copy_other_contact_body(params)
    )
    |> Response.handle_person_response()
  end

  defp resource_path(resource_name) do
    resource_name
    |> String.split("/")
    |> Enum.map(fn segment -> URI.encode(segment, &URI.char_unreserved?/1) end)
    |> Enum.join("/")
  end
end
