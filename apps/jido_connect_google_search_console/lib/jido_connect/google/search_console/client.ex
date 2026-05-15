defmodule Jido.Connect.Google.SearchConsole.Client do
  @moduledoc """
  Google Search Console API client boundary.

  Endpoint-specific client modules:

    * `Sites` – site list and add operations
    * `SearchAnalytics` – search analytics query operations
  """

  defdelegate list_sites(params, access_token), to: __MODULE__.Sites
  defdelegate add_site(params, access_token), to: __MODULE__.Sites
  defdelegate query_search_analytics(params, access_token), to: __MODULE__.SearchAnalytics
end
