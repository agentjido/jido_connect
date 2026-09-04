defmodule Jido.Connect.MicrosoftSharepoint.Actions.Sites do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @sites_read "Sites.Read.All"
  @resolver Jido.Connect.MicrosoftSharepoint.ScopeResolver

  actions do
    action :resolve_site do
      id("microsoft.sharepoint.site.resolve")
      resource(:site)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Resolve SharePoint site")
      description("Resolve a SharePoint site from its tenant hostname and relative path.")
      handler(Jido.Connect.MicrosoftSharepoint.Handlers.Actions.ResolveSite)
      effect(:read)

      access do
        auth([:user, :application], default: :user)
        scopes([@sites_read], resolver: @resolver)
      end

      input do
        field(:hostname, :string,
          required?: true,
          example: "contoso.sharepoint.com",
          min_length: 1,
          max_length: 255
        )

        field(:relative_path, :string,
          required?: true,
          example: "/sites/operations",
          min_length: 1,
          max_length: 2_048
        )
      end

      output do
        field(:site, :map)
      end
    end

    action :get_site do
      id("microsoft.sharepoint.site.get")
      resource(:site)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get SharePoint site")
      description("Get SharePoint site metadata by site id.")
      handler(Jido.Connect.MicrosoftSharepoint.Handlers.Actions.GetSite)
      effect(:read)

      access do
        auth([:user, :application], default: :user)
        policies([:sharepoint_resource_access])
        scopes([@sites_read], resolver: @resolver)
      end

      input do
        field(:site_id, :string, required?: true, min_length: 1, max_length: 512)
      end

      output do
        field(:site, :map)
      end
    end

    action :search_sites do
      id("microsoft.sharepoint.sites.search")
      resource(:site)
      verb(:search)
      data_classification(:workspace_metadata)
      label("Search SharePoint sites")

      description(
        "Search SharePoint sites in the tenant. This action requires tenant-wide read access."
      )

      handler(Jido.Connect.MicrosoftSharepoint.Handlers.Actions.SearchSites)
      effect(:read)

      access do
        auth([:user, :application], default: :user)
        scopes([@sites_read], resolver: @resolver)
      end

      input do
        field(:query, :string, required?: true, min_length: 1, max_length: 256)
        field(:page_size, :integer, default: 25, minimum: 1, maximum: 200)
      end

      output do
        field(:sites, {:array, :map})
        field(:next_link, :string)
      end
    end
  end
end
