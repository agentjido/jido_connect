defmodule Jido.Connect.MicrosoftSharepoint.Client.Sites do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftSharepoint.{GraphPath, Normalizer, Query}
  alias Jido.Connect.MicrosoftSharepoint.Client.Response

  def resolve(access_token, input) do
    with {:ok, url} <-
           GraphPath.site_by_path(Map.get(input, :hostname), Map.get(input, :relative_path)) do
      access_token
      |> Transport.request()
      |> Transport.request(:get, url: url)
      |> Response.single(&Normalizer.site/1, :site, "Failed to resolve SharePoint site")
    end
  end

  def get(access_token, input) do
    with {:ok, url} <- GraphPath.site(Map.get(input, :site_id)) do
      access_token
      |> Transport.request()
      |> Transport.request(:get, url: url)
      |> Response.single(&Normalizer.site/1, :site, "Failed to get SharePoint site")
    end
  end

  def search(access_token, input) do
    query = Map.get(input, :query)

    if is_binary(query) and String.trim(query) != "" do
      params = Query.page(input, %{search: query})

      access_token
      |> Transport.request()
      |> Transport.request(:get, url: "/sites", params: params)
      |> Response.page(&Normalizer.site/1, :sites, "Failed to search SharePoint sites")
    else
      {:error, Error.config("SharePoint site search query is required", key: :query)}
    end
  end
end
