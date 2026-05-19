defmodule Jido.Connect.MicrosoftOnedrive.Actions.Read do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @files_read "Files.Read"
  @scope_resolver Jido.Connect.MicrosoftOnedrive.ScopeResolver

  actions do
    action :list_items do
      id("microsoft.onedrive.items.list")
      resource(:drive_item)
      verb(:list)
      data_classification(:personal_data)
      label("List Microsoft OneDrive items")
      description("List items in the root of the authenticated user's OneDrive.")
      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.ListItems)
      effect(:read)

      access do
        auth(:user)
        scopes([@files_read], resolver: @scope_resolver)
      end

      input do
        field(:page_size, :integer, default: 25)
      end

      output do
        field(:items, {:array, :map})
        field(:next_link, :string)
      end
    end

    action :get_item do
      id("microsoft.onedrive.item.get")
      resource(:drive_item)
      verb(:get)
      data_classification(:personal_data)
      label("Get Microsoft OneDrive item")
      description("Fetch a single Microsoft OneDrive drive item by id.")
      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.GetItem)
      effect(:read)

      access do
        auth(:user)
        scopes([@files_read], resolver: @scope_resolver)
      end

      input do
        field(:item_id, :string, required?: true, example: "01ABCD1234...")
      end

      output do
        field(:item, :map)
      end
    end

    action :get_drive do
      id("microsoft.onedrive.drive.get")
      resource(:drive)
      verb(:get)
      data_classification(:personal_data)
      label("Get Microsoft OneDrive drive")
      description("Fetch the authenticated user's default OneDrive drive metadata.")
      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.GetDrive)
      effect(:read)

      access do
        auth(:user)
        scopes([@files_read], resolver: @scope_resolver)
      end

      input do
      end

      output do
        field(:drive, :map)
      end
    end
  end
end
