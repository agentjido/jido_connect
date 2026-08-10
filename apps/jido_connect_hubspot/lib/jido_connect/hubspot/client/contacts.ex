defmodule Jido.Connect.HubSpot.Client.Contacts do
  @moduledoc "HubSpot CRM v3 API boundary for contact reads and search."

  alias Jido.Connect.Http
  alias Jido.Connect.HubSpot.Client.{Params, Response, Transport}
  alias Jido.Connect.HubSpot.Normalizer

  @object_path "/crm/v3/objects/contacts"

  @doc "Gets a single HubSpot contact by ID."
  def get_contact(%{contact_id: contact_id} = params, access_token)
      when is_binary(contact_id) and is_binary(access_token) do
    defaults = [properties: Params.default_contact_properties()]

    access_token
    |> Transport.api_request()
    |> Req.get(
      url:
        Http.url_with_query(
          "#{@object_path}/#{contact_id}",
          Params.get_params(params, defaults)
        )
    )
    |> Response.handle_get_response(&Normalizer.contact/1)
  end

  @doc "Lists HubSpot contacts with optional pagination and property selection."
  def list_contacts(params, access_token) when is_map(params) and is_binary(access_token) do
    defaults = [properties: Params.default_contact_properties()]

    access_token
    |> Transport.api_request()
    |> Req.get(url: Http.url_with_query(@object_path, Params.list_params(params, defaults)))
    |> Response.handle_list_response(&Normalizer.contact/1)
  end

  @doc "Searches HubSpot contacts with query or filter groups."
  def search_contacts(params, access_token) when is_map(params) and is_binary(access_token) do
    defaults = [properties: Params.default_contact_properties()]

    access_token
    |> Transport.api_request()
    |> Req.post(
      url: "#{@object_path}/search",
      json: Params.search_body(params, defaults)
    )
    |> Response.handle_search_response(&Normalizer.contact/1)
  end

  @doc "Creates a new HubSpot CRM contact."
  def create_contact(params, access_token) when is_map(params) and is_binary(access_token) do
    body = Params.contact_write_body(params)

    access_token
    |> Transport.api_request()
    |> Req.post(
      url: @object_path,
      json: body
    )
    |> Response.handle_get_response(&Normalizer.contact/1)
  end

  @doc "Updates an existing HubSpot CRM contact by ID."
  def update_contact(%{contact_id: contact_id} = params, access_token)
      when is_binary(contact_id) and is_binary(access_token) do
    body = Params.contact_write_body(params)

    access_token
    |> Transport.api_request()
    |> Req.patch(
      url: "#{@object_path}/#{contact_id}",
      json: body
    )
    |> Response.handle_get_response(&Normalizer.contact/1)
  end
end
