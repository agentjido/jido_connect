defmodule Jido.Connect.Google.SearchConsole.Handlers.Actions.ListSitemapsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.SearchConsole.Handlers.Actions.ListSitemaps
  alias Jido.Connect.Google.SearchConsole.Sitemap

  defmodule FakeSitemapsClient do
    def list_sitemaps(%{site_url: "https://example.com/"}, "token") do
      {:ok,
       %{
         sitemaps: [
           Sitemap.new!(%{
             path: "https://example.com/sitemap.xml",
             last_submitted: "2026-01-15T10:30:00Z",
             is_pending: false,
             error_count: 0,
             warnings_count: 1,
             type: "SITEMAP"
           }),
           Sitemap.new!(%{
             path: "https://example.com/sitemap2.xml",
             is_pending: true,
             error_count: 2,
             warnings_count: 0
           })
         ]
       }}
    end

    def list_sitemaps(%{site_url: "https://empty.com/"}, "token") do
      {:ok, %{sitemaps: []}}
    end
  end

  @fake_credentials %{access_token: "token", google_search_console_client: FakeSitemapsClient}

  describe "run/2 site_url validation" do
    test "returns error when site_url is missing" do
      assert {:error, %{reason: :invalid_sitemap_list_request}} =
               ListSitemaps.run(%{}, %{credentials: %{access_token: "token"}})
    end

    test "returns error when site_url is empty string" do
      assert {:error, %{reason: :invalid_sitemap_list_request}} =
               ListSitemaps.run(%{site_url: ""}, %{credentials: %{access_token: "token"}})
    end

    test "returns error when site_url is blank" do
      assert {:error, %{reason: :invalid_sitemap_list_request}} =
               ListSitemaps.run(%{site_url: "   "}, %{credentials: %{access_token: "token"}})
    end
  end

  describe "run/2 with valid site_url" do
    test "returns normalized sitemaps list" do
      assert {:ok, %{sitemaps: sitemaps}} =
               ListSitemaps.run(%{site_url: "https://example.com/"}, %{
                 credentials: @fake_credentials
               })

      assert length(sitemaps) == 2

      [first, second] = sitemaps
      assert first.path == "https://example.com/sitemap.xml"
      assert first.warnings_count == 1
      assert second.path == "https://example.com/sitemap2.xml"
      assert second.is_pending == true
      assert second.error_count == 2
    end

    test "returns empty sitemaps list when none found" do
      assert {:ok, %{sitemaps: []}} =
               ListSitemaps.run(%{site_url: "https://empty.com/"}, %{
                 credentials: @fake_credentials
               })
    end
  end
end
