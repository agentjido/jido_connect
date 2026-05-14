defmodule Jido.Connect.Google.Drive.Actions.Write do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @file_scope "https://www.googleapis.com/auth/drive.file"
  @scope_resolver Jido.Connect.Google.Drive.ScopeResolver
  @auth_profiles [:user, :service_account, :domain_delegated_service_account]

  actions do
    action :create_file do
      id("google.drive.file.create")
      resource(:file)
      verb(:create)
      data_classification(:workspace_metadata)
      label("Create file metadata")
      description("Create a Google Drive file metadata record without uploading media bytes.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.CreateFile)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@file_scope], resolver: @scope_resolver)
      end

      input do
        field(:name, :string, required?: true, example: "Untitled")
        field(:mime_type, :string)
        field(:description, :string)
        field(:parents, {:array, :string}, default: [])
        field(:starred, :boolean)
        field(:fields, :string)
        field(:supports_all_drives, :boolean, default: false)
      end

      output do
        field(:file, :map)
      end
    end

    action :create_folder do
      id("google.drive.folder.create")
      resource(:folder)
      verb(:create)
      data_classification(:workspace_metadata)
      label("Create folder")
      description("Create a Google Drive folder.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.CreateFolder)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@file_scope], resolver: @scope_resolver)
      end

      input do
        field(:name, :string, required?: true, example: "Reports")
        field(:parents, {:array, :string}, default: [])
        field(:fields, :string)
        field(:supports_all_drives, :boolean, default: false)
      end

      output do
        field(:folder, :map)
      end
    end

    action :copy_file do
      id("google.drive.file.copy")
      resource(:file)
      verb(:create)
      data_classification(:workspace_metadata)
      label("Copy file")
      description("Copy a Google Drive file and return copied file metadata.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.CopyFile)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@file_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:name, :string)
        field(:description, :string)
        field(:parents, {:array, :string}, default: [])
        field(:fields, :string)
        field(:supports_all_drives, :boolean, default: false)
      end

      output do
        field(:file, :map)
      end
    end

    action :update_file do
      id("google.drive.file.update")
      resource(:file)
      verb(:update)
      data_classification(:workspace_metadata)
      label("Update file metadata")

      description(
        "Update Google Drive file metadata such as name, description, parents, or starred state."
      )

      handler(Jido.Connect.Google.Drive.Handlers.Actions.UpdateFile)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@file_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:name, :string)
        field(:description, :string)
        field(:starred, :boolean)
        field(:add_parents, :string)
        field(:remove_parents, :string)
        field(:fields, :string)
        field(:supports_all_drives, :boolean, default: false)
      end

      output do
        field(:file, :map)
      end
    end
  end
end
