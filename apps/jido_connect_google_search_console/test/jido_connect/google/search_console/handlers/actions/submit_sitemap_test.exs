defmodule Jido.Connect.Google.SearchConsole.Handlers.Actions.SubmitSitemapTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.SearchConsole.Handlers.Actions.SubmitSitemap

  defmodule FakeSitemapsClient do
    def submit_sitemap(
          %{site_url: "https://example.com/", sitemap_path: "https://example.com/sitemap.xml"},
          "token"
        ) do
      {:ok, %{path: "https://example.com/sitemap.xml", submitted: true}}
    end
  end

  @fake_credentials %{access_token: "token", google_search_console_client: FakeSitemapsClient}

  describe "run/2 input validation" do
    test "returns error when site_url is missing" do
      assert {:error, %{reason: :invalid_sitemap_submit_request}} =
               SubmitSitemap.run(
                 %{sitemap_path: "https://example.com/sitemap.xml"},
                 %{credentials: %{access_token: "token"}}
               )
    end

    test "returns error when site_url is empty string" do
      assert {:error, %{reason: :invalid_sitemap_submit_request}} =
               SubmitSitemap.run(
                 %{site_url: "", sitemap_path: "https://example.com/sitemap.xml"},
                 %{credentials: %{access_token: "token"}}
               )
    end

    test "returns error when site_url is blank" do
      assert {:error, %{reason: :invalid_sitemap_submit_request}} =
               SubmitSitemap.run(
                 %{site_url: "   ", sitemap_path: "https://example.com/sitemap.xml"},
                 %{credentials: %{access_token: "token"}}
               )
    end

    test "returns error when sitemap_path is missing" do
      assert {:error, %{reason: :invalid_sitemap_submit_request}} =
               SubmitSitemap.run(
                 %{site_url: "https://example.com/"},
                 %{credentials: %{access_token: "token"}}
               )
    end

    test "returns error when sitemap_path is empty string" do
      assert {:error, %{reason: :invalid_sitemap_submit_request}} =
               SubmitSitemap.run(
                 %{site_url: "https://example.com/", sitemap_path: ""},
                 %{credentials: %{access_token: "token"}}
               )
    end

    test "returns error when sitemap_path is blank" do
      assert {:error, %{reason: :invalid_sitemap_submit_request}} =
               SubmitSitemap.run(
                 %{site_url: "https://example.com/", sitemap_path: "   "},
                 %{credentials: %{access_token: "token"}}
               )
    end
  end

  describe "run/2 with valid inputs" do
    test "submits sitemap and returns normalized result" do
      assert {:ok, %{path: path, submitted: true}} =
               SubmitSitemap.run(
                 %{
                   site_url: "https://example.com/",
                   sitemap_path: "https://example.com/sitemap.xml"
                 },
                 %{credentials: @fake_credentials}
               )

      assert path == "https://example.com/sitemap.xml"
    end
  end
end
