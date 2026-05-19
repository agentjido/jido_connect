defmodule Jido.Connect.MicrosoftOnedrive.Actions.Read do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @files_read "Files.Read"
  @files_read_all "Files.Read.All"
  @scope_resolver Jido.Connect.MicrosoftOnedrive.ScopeResolver

  actions do
    action :list_items do
      id("microsoft.onedrive.items.list")
      resource(:drive_item)
      verb(:list)
      data_classification(:personal_data)
      label("List Microsoft OneDrive items")

      description("List children of the authenticated user's OneDrive root or a specific folder.")

      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.ListItems)
      effect(:read)

      access do
        auth(:user)
        scopes([@files_read], resolver: @scope_resolver)
      end

      input do
        field(:parent_id, :string,
          description: "Parent item id. Defaults to the drive root when absent."
        )

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

    action :list_drives do
      id("microsoft.onedrive.drives.list")
      resource(:drive)
      verb(:list)
      data_classification(:personal_data)
      label("List Microsoft OneDrive drives")

      description("List drives available to the authenticated user via Microsoft Graph.")

      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.ListDrives)
      effect(:read)

      access do
        auth(:user)
        scopes([@files_read_all], resolver: @scope_resolver)
      end

      input do
        field(:page_size, :integer, default: 25)
      end

      output do
        field(:drives, {:array, :map})
        field(:next_link, :string)
      end
    end

    action :search do
      id("microsoft.onedrive.items.search")
      resource(:drive_item)
      verb(:list)
      data_classification(:personal_data)
      label("Search Microsoft OneDrive items")

      description(
        "Search for drive items matching a query across the authenticated user's OneDrive."
      )

      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.Search)
      effect(:read)

      access do
        auth(:user)
        scopes([@files_read], resolver: @scope_resolver)
      end

      input do
        field(:query, :string, required?: true, example: "Quarterly Report")
        field(:page_size, :integer, default: 25)
      end

      output do
        field(:items, {:array, :map})
        field(:next_link, :string)
      end
    end

    action :download_content do
      id("microsoft.onedrive.item.download")
      resource(:drive_item)
      verb(:download)
      data_classification(:personal_data)
      label("Download Microsoft OneDrive item content")

      description("Download the binary content of a Microsoft OneDrive drive item.")

      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.DownloadContent)
      effect(:read)

      access do
        auth(:user)
        scopes([@files_read], resolver: @scope_resolver)
      end

      input do
        field(:item_id, :string, required?: true, example: "01ABCD1234...")
      end

      output do
        field(:content, :map)
      end
    end

    action :delta do
      id("microsoft.onedrive.items.delta")
      resource(:drive_item)
      verb(:list)
      data_classification(:personal_data)
      label("Track Microsoft OneDrive changes")

      description("Track changes to drive items using the Microsoft Graph delta endpoint.")

      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.Delta)
      effect(:read)

      access do
        auth(:user)
        scopes([@files_read], resolver: @scope_resolver)
      end

      input do
        field(:token, :string,
          description: "Delta token from a previous delta response. Omit for initial sync."
        )
      end

      output do
        field(:items, {:array, :map})
        field(:next_link, :string)
        field(:delta_link, :string)
        field(:delta_token, :string)
      end
    end
  end
end
