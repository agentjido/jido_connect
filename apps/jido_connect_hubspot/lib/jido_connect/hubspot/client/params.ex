defmodule Jido.Connect.HubSpot.Client.Params do
  @moduledoc "HubSpot CRM v3 API request parameter helpers."

  alias Jido.Connect.Data

  @default_contact_properties [
    "email",
    "firstname",
    "lastname",
    "phone",
    "company",
    "jobtitle",
    "website",
    "lifecyclestage",
    "createdate",
    "lastmodifieddate",
    "hs_lead_status"
  ]

  @default_company_properties [
    "name",
    "domain",
    "industry",
    "city",
    "state",
    "country",
    "phone",
    "website",
    "description",
    "type",
    "numberofemployees",
    "annualrevenue",
    "createdate",
    "lastmodifieddate"
  ]

  @default_deal_properties [
    "dealname",
    "amount",
    "dealstage",
    "pipeline",
    "closedate",
    "deal_currency_code",
    "hubspot_owner_id",
    "description",
    "dealtype",
    "probability",
    "createdate",
    "lastmodifieddate"
  ]

  def default_contact_properties, do: @default_contact_properties
  def default_company_properties, do: @default_company_properties
  def default_deal_properties, do: @default_deal_properties

  @doc "Builds query params for CRM object get requests."
  def get_params(params, defaults) do
    properties = Data.get(params, :properties, Data.get(defaults, :properties, []))

    %{
      properties: properties,
      propertiesWithHistory: Data.get(params, :properties_with_history),
      associations: Data.get(params, :associations),
      archived: Data.get(params, :archived, false)
    }
    |> query_params()
  end

  @doc "Builds query params for CRM object list requests."
  def list_params(params, defaults) do
    properties = Data.get(params, :properties, Data.get(defaults, :properties, []))

    %{
      limit: Data.get(params, :limit, Data.get(defaults, :limit, 100)),
      after: Data.get(params, :after),
      properties: properties,
      propertiesWithHistory: Data.get(params, :properties_with_history),
      associations: Data.get(params, :associations),
      archived: Data.get(params, :archived, false)
    }
    |> query_params()
  end

  @doc "Builds the JSON body for CRM object search requests."
  def search_body(params, defaults) do
    properties = Data.get(params, :properties, Data.get(defaults, :properties, []))

    body = %{
      query: Data.get(params, :query),
      limit: Data.get(params, :limit, Data.get(defaults, :limit, 100)),
      after: Data.get(params, :after),
      properties: properties,
      sorts: Data.get(params, :sorts),
      filterGroups: Data.get(params, :filter_groups)
    }

    body = maybe_put_archived(body, Data.get(params, :archived))

    body
    |> Data.compact()
  end

  defp maybe_put_archived(body, true), do: Map.put(body, :archived, true)
  defp maybe_put_archived(body, _), do: body

  defp query_params(params) do
    params
    |> Data.compact()
    |> Enum.flat_map(fn
      {_key, []} ->
        []

      {key, values} when is_list(values) ->
        Enum.map(values, &{key, &1})

      pair ->
        [pair]
    end)
  end
end
