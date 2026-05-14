defmodule Jido.Connect.Google.Drive.Triggers.Changes do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @metadata_scope "https://www.googleapis.com/auth/drive.metadata.readonly"
  @scope_resolver Jido.Connect.Google.Drive.ScopeResolver
  @auth_profiles [:user, :service_account, :domain_delegated_service_account]

  triggers do
    poll :file_changed do
      id("google.drive.file.changed")
      resource(:file)
      verb(:watch)
      data_classification(:workspace_metadata)
      label("File changed")
      description("Poll Google Drive changes for file metadata updates, removals, and creations.")
      interval_ms(300_000)
      checkpoint(:page_token)
      dedupe(%{key: [:change_id, :file_id]})
      handler(Jido.Connect.Google.Drive.Handlers.Triggers.FileChangedPoller)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      config do
        field(:page_size, :integer, default: 100)
        field(:fields, :string)
        field(:spaces, :string, default: "drive")
        field(:drive_id, :string)
        field(:include_items_from_all_drives, :boolean, default: false)
        field(:include_removed, :boolean, default: true)
        field(:restrict_to_my_drive, :boolean, default: false)
        field(:supports_all_drives, :boolean, default: false)
      end

      signal do
        field(:change_id, :string)
        field(:file_id, :string)
        field(:removed, :boolean)
        field(:time, :string)
        field(:drive_id, :string)
        field(:change_type, :string)
        field(:file, :map)
      end
    end
  end
end
