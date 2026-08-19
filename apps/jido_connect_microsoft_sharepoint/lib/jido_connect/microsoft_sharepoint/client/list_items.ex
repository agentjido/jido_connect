defmodule Jido.Connect.MicrosoftSharepoint.Client.ListItems do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftSharepoint.{GraphPath, Normalizer, Query}
  alias Jido.Connect.MicrosoftSharepoint.Client.Response

  def list(access_token, input) do
    with {:ok, url} <- items_url(input),
         {:ok, params} <- Query.item_params(input) do
      access_token
      |> Transport.request()
      |> Transport.request(:get, url: url, params: params)
      |> Response.page(&Normalizer.list_item/1, :items, "Failed to list SharePoint list items")
    end
  end

  def get(access_token, input) do
    with {:ok, url} <-
           GraphPath.resource_path([
             "sites",
             Map.get(input, :site_id),
             "lists",
             Map.get(input, :list_id),
             "items",
             Map.get(input, :item_id)
           ]),
         {:ok, params} <-
           Query.item_params(Map.drop(input, [:filter_field, :filter_operator, :filter_value])) do
      access_token
      |> Transport.request()
      |> Transport.request(:get, url: url, params: Map.drop(params, [:"$top", :"$skip"]))
      |> Response.single(&Normalizer.list_item/1, :item, "Failed to get SharePoint list item")
    end
  end

  defp items_url(input) do
    GraphPath.resource_path([
      "sites",
      Map.get(input, :site_id),
      "lists",
      Map.get(input, :list_id),
      "items"
    ])
  end
end
