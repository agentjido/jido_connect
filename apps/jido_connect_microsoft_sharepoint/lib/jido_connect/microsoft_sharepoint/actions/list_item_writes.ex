defmodule Jido.Connect.MicrosoftSharepoint.Actions.ListItemWrites do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @sites_write "Sites.ReadWrite.All"
  @resolver Jido.Connect.MicrosoftSharepoint.ScopeResolver

  actions do
    action :create_list_item do
      id("microsoft.sharepoint.list.item.create")
      resource(:list_item)
      verb(:create)
      data_classification(:workspace_content)
      label("Create SharePoint list item")
      description("Create an item in a SharePoint list from validated field values.")
      handler(Jido.Connect.MicrosoftSharepoint.Handlers.Actions.CreateListItem)
      preview(Jido.Connect.MicrosoftSharepoint.Previews.CreateListItem)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth([:user, :application], default: :user)
        policies([:sharepoint_resource_access])
        scopes([@sites_write], resolver: @resolver)
      end

      input do
        field(:site_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:list_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:fields, :map, required?: true)
      end

      output do
        field(:item, :map)
      end
    end

    action :update_list_item do
      id("microsoft.sharepoint.list.item.update")
      resource(:list_item)
      verb(:update)
      data_classification(:workspace_content)
      label("Update SharePoint list item")
      description("Update SharePoint list item fields when its ETag still matches.")
      handler(Jido.Connect.MicrosoftSharepoint.Handlers.Actions.UpdateListItem)
      preview(Jido.Connect.MicrosoftSharepoint.Previews.UpdateListItem)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:user, :application], default: :user)
        policies([:sharepoint_resource_access])
        scopes([@sites_write], resolver: @resolver)
      end

      input do
        field(:site_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:list_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:item_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:etag, :string, required?: true, min_length: 1, max_length: 512)
        field(:fields, :map, required?: true)
      end

      output do
        field(:item, :map)
      end
    end

    action :delete_list_item do
      id("microsoft.sharepoint.list.item.delete")
      resource(:list_item)
      verb(:delete)
      data_classification(:workspace_content)
      label("Delete SharePoint list item")
      description("Delete a SharePoint list item when its ETag still matches.")
      handler(Jido.Connect.MicrosoftSharepoint.Handlers.Actions.DeleteListItem)
      preview(Jido.Connect.MicrosoftSharepoint.Previews.DeleteListItem)
      effect(:destructive, confirmation: :always)

      access do
        auth([:user, :application], default: :user)
        policies([:sharepoint_resource_access])
        scopes([@sites_write], resolver: @resolver)
      end

      input do
        field(:site_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:list_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:item_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:etag, :string, required?: true, min_length: 1, max_length: 512)
      end

      output do
        field(:deleted, :boolean)
        field(:item_id, :string)
      end
    end
  end
end
