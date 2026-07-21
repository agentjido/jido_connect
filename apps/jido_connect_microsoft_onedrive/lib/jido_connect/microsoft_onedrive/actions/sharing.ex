defmodule Jido.Connect.MicrosoftOnedrive.Actions.Sharing do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @files_read_write "Files.ReadWrite"
  @scope_resolver Jido.Connect.MicrosoftOnedrive.ScopeResolver

  @sharing_link_types ["view", "edit", "embed"]

  actions do
    action :create_sharing_link do
      id("microsoft.onedrive.item.create_link")
      resource(:permission)
      verb(:share)
      data_classification(:personal_data)
      label("Create Microsoft OneDrive sharing link")
      description("Create a sharing link for a Microsoft OneDrive drive item.")
      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.CreateSharingLink)
      effect(:external_write, confirmation: :always)

      access do
        auth(:user)
        scopes([@files_read_write], resolver: @scope_resolver)
      end

      input do
        field(:item_id, :string, required?: true, example: "01ABCD1234...")
        field(:type, :string, required?: true, enum: @sharing_link_types, example: "view")
        field(:scope, :string, description: "Link scope: anonymous, organization, or users")
        field(:password, :string, description: "Password for the sharing link")
        field(:expiration_date_time, :string, description: "ISO 8601 expiration timestamp")
        field(:retain_inherited_permissions, :boolean, default: true)
      end

      output do
        field(:permission, :map)
      end
    end
  end
end
