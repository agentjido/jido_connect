defmodule Jido.Connect.Google.Drive.Actions.FileContent do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @file_scope "https://www.googleapis.com/auth/drive.file"
  @readonly_scope "https://www.googleapis.com/auth/drive.readonly"
  @scope_resolver Jido.Connect.Google.Drive.ScopeResolver
  @auth_profiles [:user, :service_account, :domain_delegated_service_account]

  actions do
    action :export_file do
      id("google.drive.file.export")
      resource(:file)
      verb(:download)
      data_classification(:workspace_content)
      label("Export file content")
      description("Export Google Workspace Drive file content to the requested MIME type.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.ExportFile)
      effect(:read)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:mime_type, :string, required?: true, example: "application/pdf")
      end

      output do
        field(:file_content, :map)
      end
    end

    action :download_file do
      id("google.drive.file.download")
      resource(:file)
      verb(:download)
      data_classification(:workspace_content)
      label("Download file content")
      description("Download raw content bytes for a non-Google-Workspace Drive file.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.DownloadFile)
      effect(:read)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:supports_all_drives, :boolean, default: false)
      end

      output do
        field(:file_content, :map)
      end
    end

    action :delete_file do
      id("google.drive.file.delete")
      resource(:file)
      verb(:delete)
      data_classification(:workspace_metadata)
      label("Delete file")
      description("Permanently delete a Google Drive file that the app is allowed to manage.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.DeleteFile)
      effect(:destructive, confirmation: :always)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@file_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:supports_all_drives, :boolean, default: false)
      end

      output do
        field(:result, :map)
      end
    end
  end
end
