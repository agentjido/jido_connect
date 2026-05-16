defmodule Jido.Connect.HubSpot.Client.Companies do
  @moduledoc "HubSpot CRM v3 API boundary for company reads and search."

  alias Jido.Connect.HubSpot.Client.{Params, Response, Transport}
  alias Jido.Connect.HubSpot.Normalizer

  @object_path "/crm/v3/objects/companies"

  @doc "Gets a single HubSpot company by ID."
  def get_company(%{company_id: company_id} = params, access_token)
      when is_binary(company_id) and is_binary(access_token) do
    defaults = [properties: Params.default_company_properties()]

    access_token
    |> Transport.api_request()
    |> Req.get(
      url: "#{@object_path}/#{company_id}",
      params: Params.get_params(params, defaults)
    )
    |> Response.handle_get_response(&Normalizer.company/1)
  end

  @doc "Lists HubSpot companies with optional pagination and property selection."
  def list_companies(params, access_token) when is_map(params) and is_binary(access_token) do
    defaults = [properties: Params.default_company_properties()]

    access_token
    |> Transport.api_request()
    |> Req.get(
      url: @object_path,
      params: Params.list_params(params, defaults)
    )
    |> Response.handle_list_response(&Normalizer.company/1)
  end

  @doc "Searches HubSpot companies with query or filter groups."
  def search_companies(params, access_token) when is_map(params) and is_binary(access_token) do
    defaults = [properties: Params.default_company_properties()]

    access_token
    |> Transport.api_request()
    |> Req.post(
      url: "#{@object_path}/search",
      json: Params.search_body(params, defaults)
    )
    |> Response.handle_search_response(&Normalizer.company/1)
  end
end
