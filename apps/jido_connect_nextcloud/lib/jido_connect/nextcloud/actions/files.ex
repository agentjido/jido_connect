defmodule Jido.Connect.Nextcloud.Actions.Files do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Nextcloud.ScopeResolver

  actions do
    action :list_files do
      id("nextcloud.files.list")
      resource(:file)
      verb(:list)
      data_classification(:personal_data)
      label("List Nextcloud files")
      description("List children under a Nextcloud folder path using WebDAV PROPFIND.")
      handler(Jido.Connect.Nextcloud.Handlers.Actions.ListFiles)
      effect(:read)

      access do
        auth(:app_password)
        policies([:nextcloud_instance_access])
        scopes(["files:read"], resolver: @scope_resolver)
      end

      input do
        field(:path, :string, default: "/")
        field(:depth, :string, default: "1", enum: ["0", "1"])
      end

      output do
        field(:nodes, {:array, :map})
      end
    end

    action :get_file do
      id("nextcloud.file.get")
      resource(:file)
      verb(:get)
      data_classification(:personal_data)
      label("Get Nextcloud file metadata")
      description("Fetch metadata for a Nextcloud file or folder path.")
      handler(Jido.Connect.Nextcloud.Handlers.Actions.GetFile)
      effect(:read)

      access do
        auth(:app_password)
        policies([:nextcloud_instance_access])
        scopes(["files:read"], resolver: @scope_resolver)
      end

      input do
        field(:path, :string, required?: true, example: "/Documents/report.docx")
      end

      output do
        field(:node, :map)
      end
    end

    action :search_files do
      id("nextcloud.files.search")
      resource(:file)
      verb(:list)
      data_classification(:personal_data)
      label("Search Nextcloud files")
      description("Search Nextcloud files using WebDAV SEARCH.")
      handler(Jido.Connect.Nextcloud.Handlers.Actions.SearchFiles)
      effect(:read)

      access do
        auth(:app_password)
        policies([:nextcloud_instance_access])
        scopes(["files:read"], resolver: @scope_resolver)
      end

      input do
        field(:query, :string, required?: true, example: "quarterly")
        field(:scope_path, :string, default: "/")
      end

      output do
        field(:nodes, {:array, :map})
      end
    end

    action :download_file do
      id("nextcloud.file.download")
      resource(:file)
      verb(:download)
      data_classification(:personal_data)
      label("Download Nextcloud file")
      description("Download file content from Nextcloud.")
      handler(Jido.Connect.Nextcloud.Handlers.Actions.DownloadFile)
      effect(:read)

      access do
        auth(:app_password)
        policies([:nextcloud_instance_access])
        scopes(["files:read"], resolver: @scope_resolver)
      end

      input do
        field(:path, :string, required?: true, example: "/Documents/report.docx")
      end

      output do
        field(:content, :string)
        field(:content_type, :string)
        field(:etag, :string)
      end
    end

    action :create_folder do
      id("nextcloud.folder.create")
      resource(:file)
      verb(:create)
      data_classification(:personal_data)
      label("Create Nextcloud folder")
      description("Create a folder in Nextcloud using WebDAV MKCOL.")
      handler(Jido.Connect.Nextcloud.Handlers.Actions.CreateFolder)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:app_password)
        policies([:nextcloud_instance_access])
        scopes(["files:write"], resolver: @scope_resolver)
      end

      input do
        field(:path, :string, required?: true, example: "/Projects/New Folder")
      end

      output do
        field(:created, :boolean)
        field(:path, :string)
      end
    end

    action :upload_file do
      id("nextcloud.file.upload")
      resource(:file)
      verb(:upload)
      data_classification(:personal_data)
      label("Upload Nextcloud file")
      description("Upload or replace file content in Nextcloud using WebDAV PUT.")
      handler(Jido.Connect.Nextcloud.Handlers.Actions.UploadFile)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:app_password)
        policies([:nextcloud_instance_access])
        scopes(["files:write"], resolver: @scope_resolver)
      end

      input do
        field(:path, :string, required?: true, example: "/Documents/report.txt")
        field(:content, :string, required?: true)
        field(:content_type, :string, default: "application/octet-stream")
      end

      output do
        field(:uploaded, :boolean)
        field(:path, :string)
        field(:etag, :string)
      end
    end

    action :move_node do
      id("nextcloud.node.move")
      resource(:file)
      verb(:update)
      data_classification(:personal_data)
      label("Move Nextcloud file or folder")
      description("Move or rename a Nextcloud file/folder using WebDAV MOVE.")
      handler(Jido.Connect.Nextcloud.Handlers.Actions.MoveNode)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:app_password)
        policies([:nextcloud_instance_access])
        scopes(["files:write"], resolver: @scope_resolver)
      end

      input do
        field(:from_path, :string, required?: true)
        field(:to_path, :string, required?: true)
        field(:overwrite, :boolean, default: false)
      end

      output do
        field(:moved, :boolean)
        field(:from_path, :string)
        field(:to_path, :string)
      end
    end

    action :copy_node do
      id("nextcloud.node.copy")
      resource(:file)
      verb(:create)
      data_classification(:personal_data)
      label("Copy Nextcloud file or folder")
      description("Copy a Nextcloud file/folder using WebDAV COPY.")
      handler(Jido.Connect.Nextcloud.Handlers.Actions.CopyNode)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:app_password)
        policies([:nextcloud_instance_access])
        scopes(["files:write"], resolver: @scope_resolver)
      end

      input do
        field(:from_path, :string, required?: true)
        field(:to_path, :string, required?: true)
        field(:overwrite, :boolean, default: false)
      end

      output do
        field(:copied, :boolean)
        field(:from_path, :string)
        field(:to_path, :string)
      end
    end

    action :delete_node do
      id("nextcloud.node.delete")
      resource(:file)
      verb(:delete)
      data_classification(:personal_data)
      label("Delete Nextcloud file or folder")
      description("Delete a Nextcloud file or folder using WebDAV DELETE.")
      handler(Jido.Connect.Nextcloud.Handlers.Actions.DeleteNode)
      effect(:destructive, confirmation: :always)

      access do
        auth(:app_password)
        policies([:nextcloud_instance_access])
        scopes(["files:write"], resolver: @scope_resolver)
      end

      input do
        field(:path, :string, required?: true)
      end

      output do
        field(:deleted, :boolean)
        field(:path, :string)
      end
    end
  end
end
