defmodule Jido.Connect.MicrosoftOnedrive.Actions.Permissions do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @files_read "Files.Read"
  @files_read_write "Files.ReadWrite"
  @scope_resolver Jido.Connect.MicrosoftOnedrive.ScopeResolver

  @permission_roles ["read", "write", "owner"]

  actions do
    action :list_permissions do
      id("microsoft.onedrive.item.permissions.list")
      resource(:permission)
      verb(:list)
      data_classification(:personal_data)
      label("List Microsoft OneDrive item permissions")

      description("List permissions for a Microsoft OneDrive drive item.")

      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.ListPermissions)
      effect(:read)

      access do
        auth(:user)
        scopes([@files_read], resolver: @scope_resolver)
      end

      input do
        field(:item_id, :string, required?: true, example: "01ABCD1234...")
      end

      output do
        field(:permissions, {:array, :map})
      end
    end

    action :get_permission do
      id("microsoft.onedrive.item.permission.get")
      resource(:permission)
      verb(:get)
      data_classification(:personal_data)
      label("Get Microsoft OneDrive item permission")

      description("Fetch a specific permission for a Microsoft OneDrive drive item.")

      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.GetPermission)
      effect(:read)

      access do
        auth(:user)
        scopes([@files_read], resolver: @scope_resolver)
      end

      input do
        field(:item_id, :string, required?: true, example: "01ABCD1234...")
        field(:permission_id, :string, required?: true, example: "PERM1")
      end

      output do
        field(:permission, :map)
      end
    end

    action :create_permission do
      id("microsoft.onedrive.item.permission.create")
      resource(:permission)
      verb(:share)
      data_classification(:personal_data)
      label("Invite to Microsoft OneDrive item")

      description("Invite users or grant permission to a Microsoft OneDrive drive item.")

      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.CreatePermission)
      effect(:external_write, confirmation: :always)

      access do
        auth(:user)
        scopes([@files_read_write], resolver: @scope_resolver)
      end

      input do
        field(:item_id, :string, required?: true, example: "01ABCD1234...")

        field(:recipients, {:array, :map},
          required?: true,
          description: "List of %{email: \"user@example.com\"} recipients"
        )

        field(:roles, {:array, :string},
          required?: true,
          enum: @permission_roles,
          example: ["read"]
        )

        field(:send_invitation, :boolean, default: true)
        field(:message, :string, description: "Custom message for the invitation email")
        field(:require_sign_in, :boolean, default: true)
        field(:expiration_date_time, :string, description: "ISO 8601 expiration timestamp")
      end

      output do
        field(:permission, :map)
      end
    end

    action :delete_permission do
      id("microsoft.onedrive.item.permission.delete")
      resource(:permission)
      verb(:delete)
      data_classification(:personal_data)
      label("Delete Microsoft OneDrive item permission")

      description("Remove a permission from a Microsoft OneDrive drive item.")

      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.DeletePermission)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@files_read_write], resolver: @scope_resolver)
      end

      input do
        field(:item_id, :string, required?: true, example: "01ABCD1234...")
        field(:permission_id, :string, required?: true, example: "PERM1")
      end

      output do
        field(:deleted, :boolean)
        field(:permission_id, :string)
      end
    end
  end
end
