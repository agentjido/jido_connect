defmodule Jido.Connect.Google.Drive.Actions.Changes do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @metadata_scope "https://www.googleapis.com/auth/drive.metadata.readonly"
  @scope_resolver Jido.Connect.Google.Drive.ScopeResolver
  @auth_profiles [:user, :service_account, :domain_delegated_service_account]

  actions do
    action :get_start_page_token do
      id("google.drive.changes.get_start_page_token")
      resource(:change)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get Drive changes start page token")

      description(
        "Fetch the current Google Drive changes cursor for future change listing or watch setup."
      )

      handler(Jido.Connect.Google.Drive.Handlers.Actions.GetStartPageToken)
      effect(:read)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:drive_id, :string)
        field(:supports_all_drives, :boolean, default: false)
      end

      output do
        field(:start_page_token, :string)
      end
    end

    action :list_changes do
      id("google.drive.changes.list")
      resource(:change)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List Drive changes")
      description("List Google Drive changes after a provider-generated page token.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.ListChanges)
      effect(:read)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:page_token, :string,
          required?: true,
          description:
            "Provider-generated cursor from google.drive.changes.get_start_page_token or " <>
              "a previous changes.list response."
        )

        field(:page_size, :integer, default: 100)
        field(:fields, :string, description: "Google Drive changes.list fields expression.")
        field(:spaces, :string, default: "drive")
        field(:drive_id, :string)
        field(:include_items_from_all_drives, :boolean, default: false)
        field(:include_removed, :boolean, default: true)
        field(:restrict_to_my_drive, :boolean, default: false)
        field(:supports_all_drives, :boolean, default: false)
      end

      output do
        field(:changes, {:array, :map})
        field(:next_page_token, :string)
        field(:new_start_page_token, :string)
      end
    end
  end
end
