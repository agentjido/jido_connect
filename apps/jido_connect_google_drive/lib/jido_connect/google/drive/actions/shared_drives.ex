defmodule Jido.Connect.Google.Drive.Actions.SharedDrives do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  alias Jido.Connect.Google.Drive.Fields

  @drive_scope "https://www.googleapis.com/auth/drive"
  @readonly_scope "https://www.googleapis.com/auth/drive.readonly"
  @scope_resolver Jido.Connect.Google.Drive.ScopeResolver
  @auth_profiles [:user, :service_account, :domain_delegated_service_account]

  actions do
    action :list_shared_drives do
      id("google.drive.shared_drives.list")
      resource(:shared_drive)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List shared drives")
      description("List Google Drive shared drives.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.ListSharedDrives)
      effect(:read)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:page_size, :integer, default: 100)
        field(:page_token, :string)
        field(:query, :string)
        field(:use_domain_admin_access, :boolean, default: false)

        field(:fields, :string,
          description: "Google Drive drives.list fields expression.",
          metadata: %{presets: Fields.shared_drive_list_presets()}
        )
      end

      output do
        field(:shared_drives, {:array, :map})
        field(:next_page_token, :string)
      end
    end

    action :get_shared_drive do
      id("google.drive.shared_drive.get")
      resource(:shared_drive)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get shared drive")
      description("Fetch Google Drive shared-drive metadata by id.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.GetSharedDrive)
      effect(:read)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:shared_drive_id, :string, required?: true, example: "0AExample...")
        field(:use_domain_admin_access, :boolean, default: false)

        field(:fields, :string,
          description: "Google Drive drives.get fields expression.",
          metadata: %{presets: Fields.shared_drive_presets()}
        )
      end

      output do
        field(:shared_drive, :map)
      end
    end

    action :create_shared_drive do
      id("google.drive.shared_drive.create")
      resource(:shared_drive)
      verb(:create)
      data_classification(:workspace_metadata)
      label("Create shared drive")
      description("Create a Google Drive shared drive.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.CreateSharedDrive)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@drive_scope], resolver: @scope_resolver)
      end

      input do
        field(:request_id, :string, required?: true, example: "uuid")
        field(:name, :string, required?: true, example: "Team Drive")
        field(:color_rgb, :string)
        field(:theme_id, :string)
        field(:restrictions, :map)

        field(:fields, :string,
          description: "Google Drive drives.create fields expression.",
          metadata: %{presets: Fields.shared_drive_presets()}
        )
      end

      output do
        field(:shared_drive, :map)
      end
    end

    action :update_shared_drive do
      id("google.drive.shared_drive.update")
      resource(:shared_drive)
      verb(:update)
      data_classification(:workspace_metadata)
      label("Update shared drive")
      description("Update Google Drive shared-drive metadata.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.UpdateSharedDrive)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@drive_scope], resolver: @scope_resolver)
      end

      input do
        field(:shared_drive_id, :string, required?: true, example: "0AExample...")
        field(:name, :string)
        field(:color_rgb, :string)
        field(:theme_id, :string)
        field(:restrictions, :map)
        field(:use_domain_admin_access, :boolean, default: false)

        field(:fields, :string,
          description: "Google Drive drives.update fields expression.",
          metadata: %{presets: Fields.shared_drive_presets()}
        )
      end

      output do
        field(:shared_drive, :map)
      end
    end

    action :delete_shared_drive do
      id("google.drive.shared_drive.delete")
      resource(:shared_drive)
      verb(:delete)
      data_classification(:workspace_metadata)
      label("Delete shared drive")
      description("Permanently delete a Google Drive shared drive.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.DeleteSharedDrive)
      effect(:destructive, confirmation: :always)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@drive_scope], resolver: @scope_resolver)
      end

      input do
        field(:shared_drive_id, :string, required?: true, example: "0AExample...")
        field(:use_domain_admin_access, :boolean, default: false)
        field(:allow_item_deletion, :boolean, default: false)
      end

      output do
        field(:result, :map)
      end
    end

    action :hide_shared_drive do
      id("google.drive.shared_drive.hide")
      resource(:shared_drive)
      verb(:archive)
      data_classification(:workspace_metadata)
      label("Hide shared drive")
      description("Hide a Google Drive shared drive from the default view.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.HideSharedDrive)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@drive_scope], resolver: @scope_resolver)
      end

      input do
        field(:shared_drive_id, :string, required?: true, example: "0AExample...")

        field(:fields, :string,
          description: "Google Drive drives.hide fields expression.",
          metadata: %{presets: Fields.shared_drive_presets()}
        )
      end

      output do
        field(:shared_drive, :map)
      end
    end

    action :unhide_shared_drive do
      id("google.drive.shared_drive.unhide")
      resource(:shared_drive)
      verb(:unarchive)
      data_classification(:workspace_metadata)
      label("Unhide shared drive")
      description("Restore a Google Drive shared drive to the default view.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.UnhideSharedDrive)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@drive_scope], resolver: @scope_resolver)
      end

      input do
        field(:shared_drive_id, :string, required?: true, example: "0AExample...")

        field(:fields, :string,
          description: "Google Drive drives.unhide fields expression.",
          metadata: %{presets: Fields.shared_drive_presets()}
        )
      end

      output do
        field(:shared_drive, :map)
      end
    end
  end
end
