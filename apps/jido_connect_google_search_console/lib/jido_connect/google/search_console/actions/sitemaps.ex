defmodule Jido.Connect.Google.SearchConsole.Actions.Sitemaps do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @readonly_scope "https://www.googleapis.com/auth/webmasters.readonly"
  @write_scope "https://www.googleapis.com/auth/webmasters"
  @scope_resolver Jido.Connect.Google.SearchConsole.ScopeResolver

  actions do
    action :list_sitemaps do
      id("google.search_console.sitemap.list")
      resource(:sitemap)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List Search Console sitemaps")
      description("List sitemaps submitted for a site in Google Search Console.")
      handler(Jido.Connect.Google.SearchConsole.Handlers.Actions.ListSitemaps)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:site_url, :string,
          required?: true,
          example: "https://example.com/"
        )

        field(:sitemap_index, :string, example: "https://example.com/sitemap_index.xml")
      end

      output do
        field(:sitemaps, {:array, :map})
      end
    end

    action :submit_sitemap do
      id("google.search_console.sitemap.submit")
      resource(:sitemap)
      verb(:create)
      data_classification(:workspace_metadata)
      label("Submit Search Console sitemap")
      description("Submit a sitemap for a site in Google Search Console.")
      handler(Jido.Connect.Google.SearchConsole.Handlers.Actions.SubmitSitemap)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@write_scope], resolver: @scope_resolver)
      end

      input do
        field(:site_url, :string,
          required?: true,
          example: "https://example.com/"
        )

        field(:sitemap_path, :string,
          required?: true,
          example: "https://example.com/sitemap.xml"
        )

        field(:fields, :string)
      end

      output do
        field(:path, :string)
        field(:submitted, :boolean)
      end
    end
  end
end
