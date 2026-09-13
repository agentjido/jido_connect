defmodule Jido.Connect.MicrosoftSharepoint.Client.Lists do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftSharepoint.{GraphPath, Normalizer, Query}
  alias Jido.Connect.MicrosoftSharepoint.Client.Response

  def list(access_token, input) do
    with {:ok, url} <- GraphPath.resource_path(["sites", Map.get(input, :site_id), "lists"]) do
      params = Query.page(input)

      access_token
      |> Transport.request()
      |> Transport.request(:get, url: url, params: params)
      |> Response.page(&Normalizer.site_list/1, :lists, "Failed to list SharePoint lists")
    end
  end

  def get(access_token, input) do
    with {:ok, url} <-
           GraphPath.resource_path([
             "sites",
             Map.get(input, :site_id),
             "lists",
             Map.get(input, :list_id)
           ]) do
      access_token
      |> Transport.request()
      |> Transport.request(:get, url: url)
      |> Response.single(&Normalizer.site_list/1, :list, "Failed to get SharePoint list")
    end
  end

  def list_columns(access_token, input) do
    with {:ok, url} <-
           GraphPath.resource_path([
             "sites",
             Map.get(input, :site_id),
             "lists",
             Map.get(input, :list_id),
             "columns"
           ]) do
      params = Query.page(input)

      access_token
      |> Transport.request()
      |> Transport.request(:get, url: url, params: params)
      |> Response.page(&Normalizer.column/1, :columns, "Failed to list SharePoint columns")
    end
  end
end
