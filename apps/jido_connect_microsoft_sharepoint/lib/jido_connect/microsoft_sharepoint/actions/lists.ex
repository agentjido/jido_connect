defmodule Jido.Connect.MicrosoftSharepoint.Actions.Lists do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @sites_read "Sites.Read.All"
  @resolver Jido.Connect.MicrosoftSharepoint.ScopeResolver

  actions do
    action :list_lists do
      id("microsoft.sharepoint.lists.list")
      resource(:list)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List SharePoint lists")
      description("List the visible lists in a SharePoint site.")
      handler(Jido.Connect.MicrosoftSharepoint.Handlers.Actions.ListLists)
      effect(:read)

      access do
        auth([:user, :application], default: :user)
        policies([:sharepoint_resource_access])
        scopes([@sites_read], resolver: @resolver)
      end

      input do
        field(:site_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:page_size, :integer, default: 25, minimum: 1, maximum: 200)
      end

      output do
        field(:lists, {:array, :map})
        field(:next_link, :string)
      end
    end

    action :get_list do
      id("microsoft.sharepoint.list.get")
      resource(:list)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get SharePoint list")
      description("Get SharePoint list metadata by list id.")
      handler(Jido.Connect.MicrosoftSharepoint.Handlers.Actions.GetList)
      effect(:read)

      access do
        auth([:user, :application], default: :user)
        policies([:sharepoint_resource_access])
        scopes([@sites_read], resolver: @resolver)
      end

      input do
        field(:site_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:list_id, :string, required?: true, min_length: 1, max_length: 512)
      end

      output do
        field(:list, :map)
      end
    end

    action :list_columns do
      id("microsoft.sharepoint.list.columns.list")
      resource(:column)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List SharePoint columns")
      description("List column definitions for a SharePoint list.")
      handler(Jido.Connect.MicrosoftSharepoint.Handlers.Actions.ListColumns)
      effect(:read)

      access do
        auth([:user, :application], default: :user)
        policies([:sharepoint_resource_access])
        scopes([@sites_read], resolver: @resolver)
      end

      input do
        field(:site_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:list_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:page_size, :integer, default: 100, minimum: 1, maximum: 200)
      end

      output do
        field(:columns, {:array, :map})
        field(:next_link, :string)
      end
    end
  end
end
