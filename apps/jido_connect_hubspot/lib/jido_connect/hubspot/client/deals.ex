defmodule Jido.Connect.HubSpot.Client.Deals do
  @moduledoc "HubSpot CRM v3 API boundary for deal reads and search."

  alias Jido.Connect.Http
  alias Jido.Connect.HubSpot.Client.{Params, Response, Transport}
  alias Jido.Connect.HubSpot.Normalizer

  @object_path "/crm/v3/objects/deals"

  @doc "Gets a single HubSpot deal by ID."
  def get_deal(%{deal_id: deal_id} = params, access_token)
      when is_binary(deal_id) and is_binary(access_token) do
    defaults = [properties: Params.default_deal_properties()]

    access_token
    |> Transport.api_request()
    |> Req.get(
      url:
        Http.url_with_query(
          "#{@object_path}/#{deal_id}",
          Params.get_params(params, defaults)
        )
    )
    |> Response.handle_get_response(&Normalizer.deal/1)
  end

  @doc "Lists HubSpot deals with optional pagination and property selection."
  def list_deals(params, access_token) when is_map(params) and is_binary(access_token) do
    defaults = [properties: Params.default_deal_properties()]

    access_token
    |> Transport.api_request()
    |> Req.get(url: Http.url_with_query(@object_path, Params.list_params(params, defaults)))
    |> Response.handle_list_response(&Normalizer.deal/1)
  end

  @doc "Searches HubSpot deals with query or filter groups."
  def search_deals(params, access_token) when is_map(params) and is_binary(access_token) do
    defaults = [properties: Params.default_deal_properties()]

    access_token
    |> Transport.api_request()
    |> Req.post(
      url: "#{@object_path}/search",
      json: Params.search_body(params, defaults)
    )
    |> Response.handle_search_response(&Normalizer.deal/1)
  end

  @doc "Creates a new HubSpot CRM deal."
  def create_deal(params, access_token) when is_map(params) and is_binary(access_token) do
    body = Params.deal_write_body(params)

    access_token
    |> Transport.api_request()
    |> Req.post(
      url: @object_path,
      json: body
    )
    |> Response.handle_get_response(&Normalizer.deal/1)
  end

  @doc "Updates an existing HubSpot CRM deal by ID."
  def update_deal(%{deal_id: deal_id} = params, access_token)
      when is_binary(deal_id) and is_binary(access_token) do
    body = Params.deal_write_body(params)

    access_token
    |> Transport.api_request()
    |> Req.patch(
      url: "#{@object_path}/#{deal_id}",
      json: body
    )
    |> Response.handle_get_response(&Normalizer.deal/1)
  end
end
