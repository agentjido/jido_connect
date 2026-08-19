defmodule Jido.Connect.MicrosoftSharepoint.Actions.ListItems do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @sites_read "Sites.Read.All"
  @resolver Jido.Connect.MicrosoftSharepoint.ScopeResolver

  actions do
    action :list_list_items do
      id("microsoft.sharepoint.list.items.list")
      resource(:list_item)
      verb(:list)
      data_classification(:workspace_content)
      label("List SharePoint list items")
      description("List items and selected field values from a SharePoint list.")
      handler(Jido.Connect.MicrosoftSharepoint.Handlers.Actions.ListListItems)
      effect(:read)

      access do
        auth([:user, :application], default: :user)
        policies([:sharepoint_resource_access])
        scopes([@sites_read], resolver: @resolver)
      end

      input do
        field(:site_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:list_id, :string, required?: true, min_length: 1, max_length: 512)

        field(:fields, {:array, :string},
          description: "Column internal names to return. All fields are returned when absent."
        )

        field(:filter_field, :string,
          description: "One indexed column internal name for a structured filter."
        )

        field(:filter_operator, :string,
          description: "Filter operator: eq, ne, lt, le, gt, ge, or startswith."
        )

        field(:filter_value, :any)
        field(:page_size, :integer, default: 25, minimum: 1, maximum: 200)
        field(:skip, :integer, minimum: 0)
      end

      output do
        field(:items, {:array, :map})
        field(:next_link, :string)
      end
    end

    action :get_list_item do
      id("microsoft.sharepoint.list.item.get")
      resource(:list_item)
      verb(:get)
      data_classification(:workspace_content)
      label("Get SharePoint list item")
      description("Get one SharePoint list item and its selected field values.")
      handler(Jido.Connect.MicrosoftSharepoint.Handlers.Actions.GetListItem)
      effect(:read)

      access do
        auth([:user, :application], default: :user)
        policies([:sharepoint_resource_access])
        scopes([@sites_read], resolver: @resolver)
      end

      input do
        field(:site_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:list_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:item_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:fields, {:array, :string}, description: "Column internal names to return.")
      end

      output do
        field(:item, :map)
      end
    end
  end
end
