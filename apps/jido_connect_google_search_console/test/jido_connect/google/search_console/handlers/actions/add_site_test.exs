defmodule Jido.Connect.Google.SearchConsole.Handlers.Actions.AddSiteTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.SearchConsole.Site
  alias Jido.Connect.Google.SearchConsole.Handlers.Actions.AddSite

  defmodule FakeSitesClient do
    def add_site(%{site_url: "https://example.com/"}, "token") do
      {:ok, Site.new!(%{site_url: "https://example.com/", permission_level: "siteOwner"})}
    end

    def add_site(%{site_url: "http://example.com/"}, "token") do
      {:ok, Site.new!(%{site_url: "http://example.com/", permission_level: "siteOwner"})}
    end

    def add_site(%{site_url: "sc-domain:example.com"}, "token") do
      {:ok, Site.new!(%{site_url: "sc-domain:example.com", permission_level: "siteOwner"})}
    end
  end

  @fake_credentials %{access_token: "token", google_search_console_client: FakeSitesClient}

  describe "run/2 input validation" do
    test "returns error when site_url is missing" do
      assert {:error, %{reason: :invalid_site_add_request}} =
               AddSite.run(%{}, %{credentials: %{access_token: "token"}})
    end

    test "returns error when site_url is empty string" do
      assert {:error, %{reason: :invalid_site_add_request}} =
               AddSite.run(%{site_url: ""}, %{credentials: %{access_token: "token"}})
    end

    test "returns error when site_url is blank" do
      assert {:error, %{reason: :invalid_site_add_request}} =
               AddSite.run(%{site_url: "   "}, %{credentials: %{access_token: "token"}})
    end

    test "returns error when site_url is not a valid URL or domain property" do
      assert {:error, %{reason: :invalid_site_add_request}} =
               AddSite.run(%{site_url: "not-a-valid-url"}, %{
                 credentials: %{access_token: "token"}
               })
    end

    test "returns error when site_url is an integer" do
      assert {:error, %{reason: :invalid_site_add_request}} =
               AddSite.run(%{site_url: 12345}, %{credentials: %{access_token: "token"}})
    end
  end

  describe "run/2 with valid site_url" do
    test "accepts https URL and delegates to client" do
      assert {:ok, %{site: %{site_url: "https://example.com/"}}} =
               AddSite.run(%{site_url: "https://example.com/"}, %{
                 credentials: @fake_credentials
               })
    end

    test "accepts http URL and delegates to client" do
      assert {:ok, %{site: %{site_url: "http://example.com/"}}} =
               AddSite.run(%{site_url: "http://example.com/"}, %{
                 credentials: @fake_credentials
               })
    end

    test "accepts sc-domain property and delegates to client" do
      assert {:ok, %{site: %{site_url: "sc-domain:example.com"}}} =
               AddSite.run(%{site_url: "sc-domain:example.com"}, %{
                 credentials: @fake_credentials
               })
    end
  end
end
