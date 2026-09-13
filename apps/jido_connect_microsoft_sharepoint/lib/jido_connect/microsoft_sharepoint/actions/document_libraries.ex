defmodule Jido.Connect.MicrosoftSharepoint.Actions.DocumentLibraries do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @files_read_all "Files.Read.All"
  @files_write_all "Files.ReadWrite.All"
  @resolver Jido.Connect.MicrosoftSharepoint.ScopeResolver
  @preview Jido.Connect.MicrosoftSharepoint.Previews.DocumentLibraryWrite

  actions do
    action :list_libraries do
      id("microsoft.sharepoint.libraries.list")
      resource(:document_library)
      verb(:list)
      data_classification(:workspace_content)
      label("List SharePoint document libraries")
      description("List document libraries for a SharePoint site.")
      handler(Jido.Connect.MicrosoftSharepoint.Handlers.Actions.ListLibraries)
      effect(:read)

      access do
        auth([:user, :application], default: :user)
        policies([:sharepoint_resource_access])
        scopes([@files_read_all], resolver: @resolver)
      end

      input do
        field(:site_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:page_size, :integer, default: 25)
      end

      output do
        field(:libraries, {:array, :map})
        field(:next_link, :string)
      end
    end

    action :list_library_items do
      id("microsoft.sharepoint.library.items.list")
      resource(:drive_item)
      verb(:list)
      data_classification(:workspace_content)
      label("List SharePoint library items")
      description("List root items or folder children in a SharePoint document library.")
      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.ListItems)
      effect(:read)

      access do
        auth([:user, :application], default: :user)
        policies([:sharepoint_drive_access])
        scopes([@files_read_all], resolver: @resolver)
      end

      input do
        field(:drive_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:parent_id, :string, min_length: 1, max_length: 512)
        field(:page_size, :integer, default: 25)
      end

      output do
        field(:items, {:array, :map})
        field(:next_link, :string)
      end
    end

    action :get_library_item do
      id("microsoft.sharepoint.library.item.get")
      resource(:drive_item)
      verb(:get)
      data_classification(:workspace_content)
      label("Get SharePoint library item")
      description("Get a file or folder from a SharePoint document library.")
      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.GetItem)
      effect(:read)

      access do
        auth([:user, :application], default: :user)
        policies([:sharepoint_drive_access])
        scopes([@files_read_all], resolver: @resolver)
      end

      input do
        field(:drive_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:item_id, :string, required?: true, min_length: 1, max_length: 512)
      end

      output do
        field(:item, :map)
      end
    end

    action :search_library_items do
      id("microsoft.sharepoint.library.items.search")
      resource(:drive_item)
      verb(:list)
      data_classification(:workspace_content)
      label("Search SharePoint library items")
      description("Search files and folders in one SharePoint document library.")
      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.Search)
      effect(:read)

      access do
        auth([:user, :application], default: :user)
        policies([:sharepoint_drive_access])
        scopes([@files_read_all], resolver: @resolver)
      end

      input do
        field(:drive_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:query, :string, required?: true, min_length: 1, max_length: 256)
        field(:page_size, :integer, default: 25)
      end

      output do
        field(:items, {:array, :map})
        field(:next_link, :string)
      end
    end

    action :download_library_item do
      id("microsoft.sharepoint.library.item.download")
      resource(:drive_item)
      verb(:download)
      data_classification(:workspace_content)
      label("Download SharePoint library item")
      description("Download file content from a SharePoint document library.")
      handler(Jido.Connect.MicrosoftSharepoint.Handlers.Actions.DownloadLibraryItem)
      effect(:read)

      access do
        auth([:user, :application], default: :user)
        policies([:sharepoint_drive_access])
        scopes([@files_read_all], resolver: @resolver)
      end

      input do
        field(:drive_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:item_id, :string, required?: true, min_length: 1, max_length: 512)
      end

      output do
        field(:content, :map)
      end
    end

    action :delta_library_items do
      id("microsoft.sharepoint.library.items.delta")
      resource(:drive_item)
      verb(:list)
      data_classification(:workspace_content)
      label("Track SharePoint library changes")
      description("Read incremental file and folder changes in a document library.")
      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.Delta)
      effect(:read)

      access do
        auth([:user, :application], default: :user)
        policies([:sharepoint_drive_access])
        scopes([@files_read_all], resolver: @resolver)
      end

      input do
        field(:drive_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:token, :string, max_length: 4096)
      end

      output do
        field(:items, {:array, :map})
        field(:next_link, :string)
        field(:delta_link, :string)
        field(:delta_token, :string)
      end
    end

    action :create_library_folder do
      id("microsoft.sharepoint.library.folder.create")
      resource(:drive_item)
      verb(:create)
      data_classification(:workspace_content)
      label("Create SharePoint library folder")
      description("Create a folder in a SharePoint document library.")
      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.CreateItem)
      preview(@preview)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth([:user, :application], default: :user)
        policies([:sharepoint_drive_access])
        scopes([@files_write_all], resolver: @resolver)
      end

      input do
        field(:drive_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:parent_id, :string, min_length: 1, max_length: 512)
        field(:name, :string, required?: true, min_length: 1, max_length: 255)
      end

      output do
        field(:item, :map)
      end
    end

    action :upload_library_item do
      id("microsoft.sharepoint.library.item.upload")
      resource(:drive_item)
      verb(:create)
      data_classification(:workspace_content)
      label("Upload SharePoint library file")
      description("Upload or replace a small file in a SharePoint document library.")
      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.UploadItem)
      preview(@preview)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth([:user, :application], default: :user)
        policies([:sharepoint_drive_access])
        scopes([@files_write_all], resolver: @resolver)
      end

      input do
        field(:drive_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:parent_id, :string, min_length: 1, max_length: 512)
        field(:name, :string, required?: true, min_length: 1, max_length: 255)
        field(:content, :string, max_length: 10_000_000)
      end

      output do
        field(:item, :map)
      end
    end

    action :update_library_item do
      id("microsoft.sharepoint.library.item.update")
      resource(:drive_item)
      verb(:update)
      data_classification(:workspace_content)
      label("Update SharePoint library item")
      description("Rename a library item when its ETag still matches.")
      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.UpdateItem)
      preview(@preview)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:user, :application], default: :user)
        policies([:sharepoint_drive_access])
        scopes([@files_write_all], resolver: @resolver)
      end

      input do
        field(:drive_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:item_id, :string, required?: true, min_length: 1, max_length: 512)
        field(:etag, :string, required?: true, min_length: 1, max_length: 512)
        field(:name, :string, required?: true, min_length: 1, max_length: 255)
      end

      output do
        field(:item, :map)
      end
    end

    action :delete_library_item do
      id("microsoft.sharepoint.library.item.delete")
      resource(:drive_item)
      verb(:delete)
      data_classification(:workspace_content)
      label("Delete SharePoint library item")
      description("Delete a library item when its ETag still matches.")
      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.DeleteItem)
      preview(@preview)
      effect(:destructive, confirmation: :always)

      access do
        auth([:user, :application], default: :user)
        policies([:sharepoint_drive_access])
        scopes([@files_write_all], resolver: @resolver)
      end

      input do
        field(:drive_id, :string, required?: true, min_length: 1, max_length: 512)
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
