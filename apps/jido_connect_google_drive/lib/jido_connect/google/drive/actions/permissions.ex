defmodule Jido.Connect.Google.Drive.Actions.Permissions do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  alias Jido.Connect.Google.Drive.Fields

  @metadata_scope "https://www.googleapis.com/auth/drive.metadata.readonly"
  @file_scope "https://www.googleapis.com/auth/drive.file"
  @permission_types ["user", "group", "domain", "anyone"]
  @permission_roles ["owner", "organizer", "fileOrganizer", "writer", "commenter", "reader"]
  @scope_resolver Jido.Connect.Google.Drive.ScopeResolver
  @auth_profiles [:user, :service_account, :domain_delegated_service_account]

  actions do
    action :list_permissions do
      id("google.drive.permissions.list")
      resource(:permission)
      verb(:list)
      data_classification(:personal_data)
      label("List file permissions")
      description("List Google Drive permissions for a file.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.ListPermissions)
      effect(:read)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:page_size, :integer, default: 100)
        field(:page_token, :string)

        field(:fields, :string,
          description: "Google Drive permissions.list fields expression.",
          metadata: %{presets: Fields.permission_list_presets()}
        )

        field(:supports_all_drives, :boolean, default: false)
        field(:use_domain_admin_access, :boolean, default: false)
      end

      output do
        field(:permissions, {:array, :map})
        field(:next_page_token, :string)
      end
    end

    action :create_permission do
      id("google.drive.permission.create")
      resource(:permission)
      verb(:share)
      data_classification(:personal_data)
      label("Create file permission")
      description("Create a Google Drive permission for a user, group, domain, or anyone.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.CreatePermission)
      effect(:external_write, confirmation: :always)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@file_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:type, :string, required?: true, enum: @permission_types, example: "user")
        field(:role, :string, required?: true, enum: @permission_roles, example: "reader")
        field(:email_address, :string)
        field(:domain, :string)
        field(:allow_file_discovery, :boolean)
        field(:expiration_time, :string)
        field(:send_notification_email, :boolean)
        field(:email_message, :string)
        field(:transfer_ownership, :boolean, default: false)

        field(:fields, :string,
          description: "Google Drive permissions.create fields expression.",
          metadata: %{presets: Fields.permission_presets()}
        )

        field(:supports_all_drives, :boolean, default: false)
        field(:use_domain_admin_access, :boolean, default: false)
      end

      output do
        field(:permission, :map)
      end
    end

    action :get_permission do
      id("google.drive.permission.get")
      resource(:permission)
      verb(:get)
      data_classification(:personal_data)
      label("Get file permission")
      description("Fetch a Google Drive permission by file id and permission id.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.GetPermission)
      effect(:read)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:permission_id, :string, required?: true, example: "perm123")

        field(:fields, :string,
          description: "Google Drive permissions.get fields expression.",
          metadata: %{presets: Fields.permission_presets()}
        )

        field(:supports_all_drives, :boolean, default: false)
        field(:use_domain_admin_access, :boolean, default: false)
      end

      output do
        field(:permission, :map)
      end
    end

    action :update_permission do
      id("google.drive.permission.update")
      resource(:permission)
      verb(:update)
      data_classification(:personal_data)
      label("Update file permission")
      description("Update a Google Drive permission role, expiration, or discovery flag.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.UpdatePermission)
      effect(:external_write, confirmation: :always)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@file_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:permission_id, :string, required?: true, example: "perm123")
        field(:role, :string, enum: @permission_roles, example: "reader")
        field(:allow_file_discovery, :boolean)
        field(:expiration_time, :string)
        field(:remove_expiration, :boolean, default: false)
        field(:transfer_ownership, :boolean, default: false)

        field(:fields, :string,
          description: "Google Drive permissions.update fields expression.",
          metadata: %{presets: Fields.permission_presets()}
        )

        field(:supports_all_drives, :boolean, default: false)
        field(:use_domain_admin_access, :boolean, default: false)
      end

      output do
        field(:permission, :map)
      end
    end

    action :delete_permission do
      id("google.drive.permission.delete")
      resource(:permission)
      verb(:delete)
      data_classification(:personal_data)
      label("Delete file permission")
      description("Delete a Google Drive permission and revoke that principal's file access.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.DeletePermission)
      effect(:destructive, confirmation: :always)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@file_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:permission_id, :string, required?: true, example: "perm123")
        field(:supports_all_drives, :boolean, default: false)
        field(:use_domain_admin_access, :boolean, default: false)
      end

      output do
        field(:result, :map)
      end
    end
  end
end
