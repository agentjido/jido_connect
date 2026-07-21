defmodule Jido.Connect.Google.SearchConsole.Actions.Sites do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @readonly_scope "https://www.googleapis.com/auth/webmasters.readonly"
  @write_scope "https://www.googleapis.com/auth/webmasters"
  @scope_resolver Jido.Connect.Google.SearchConsole.ScopeResolver

  actions do
    action :list_sites do
      id("google.search_console.site.list")
      resource(:site)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List Search Console sites")
      description("List all sites the authenticated user has access to in Google Search Console.")
      handler(Jido.Connect.Google.SearchConsole.Handlers.Actions.ListSites)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:fields, :string)
      end

      output do
        field(:sites, {:array, :map})
      end
    end

    action :add_site do
      id("google.search_console.site.add")
      resource(:site)
      verb(:create)
      data_classification(:workspace_metadata)
      label("Add Search Console site")

      description(
        "Add a site URL or domain property to Google Search Console for the authenticated user."
      )

      handler(Jido.Connect.Google.SearchConsole.Handlers.Actions.AddSite)
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

        field(:fields, :string)
      end

      output do
        field(:site, :map)
      end
    end
  end
end
