defmodule Jido.Connect.Google.SearchConsole.Client do
  @moduledoc """
  Google Search Console API client boundary.

  Endpoint-specific client modules:

    * `Sites` – site list and add operations
    * `SearchAnalytics` – search analytics query operations
    * `Sitemaps` – sitemap list and submit operations
    * `URLInspection` – URL inspection operations
  """

  defdelegate list_sites(params, access_token), to: __MODULE__.Sites
  defdelegate add_site(params, access_token), to: __MODULE__.Sites
  defdelegate query_search_analytics(params, access_token), to: __MODULE__.SearchAnalytics
  defdelegate list_sitemaps(params, access_token), to: __MODULE__.Sitemaps
  defdelegate submit_sitemap(params, access_token), to: __MODULE__.Sitemaps
  defdelegate inspect_url(params, access_token), to: __MODULE__.URLInspection
end
