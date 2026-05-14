defmodule Jido.Connect.Google.Drive.Actions.Read do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @metadata_scope "https://www.googleapis.com/auth/drive.metadata.readonly"
  @scope_resolver Jido.Connect.Google.Drive.ScopeResolver
  @auth_profiles [:user, :service_account, :domain_delegated_service_account]

  actions do
    action :list_files do
      id("google.drive.files.list")
      resource(:file)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List files")
      description("Search or list Google Drive files with metadata fields.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.ListFiles)
      effect(:read)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:query, :string)
        field(:page_size, :integer, default: 25)
        field(:page_token, :string)
        field(:fields, :string)
        field(:order_by, :string)
        field(:spaces, :string, default: "drive")
        field(:corpora, :string)
        field(:drive_id, :string)
        field(:include_items_from_all_drives, :boolean, default: false)
        field(:supports_all_drives, :boolean, default: false)
      end

      output do
        field(:files, {:array, :map})
        field(:next_page_token, :string)
      end
    end

    action :get_file do
      id("google.drive.file.get")
      resource(:file)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get file metadata")
      description("Fetch Google Drive file metadata by file id.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.GetFile)
      effect(:read)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:fields, :string)
        field(:supports_all_drives, :boolean, default: false)
      end

      output do
        field(:file, :map)
      end
    end
  end
end
