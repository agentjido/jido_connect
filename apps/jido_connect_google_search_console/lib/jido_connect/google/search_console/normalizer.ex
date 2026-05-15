defmodule Jido.Connect.Google.SearchConsole.Normalizer do
  @moduledoc "Normalizes Google Search Console API payloads into stable package structs."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.SearchConsole.Site

  @doc "Normalizes a Search Console site entry payload."
  @spec site(map()) :: {:ok, Site.t()} | {:error, term()}
  def site(payload) when is_map(payload) do
    %{
      site_url: Data.get(payload, "siteUrl"),
      permission_level: Data.get(payload, "permissionLevel")
    }
    |> Data.compact()
    |> Site.new()
  end

  def site(_payload), do: {:error, :invalid_site_payload}
end
