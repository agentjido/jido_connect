defmodule Jido.Connect.MicrosoftOnedrive.Actions.Write do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @files_read_write "Files.ReadWrite"
  @scope_resolver Jido.Connect.MicrosoftOnedrive.ScopeResolver

  actions do
    action :create_item do
      id("microsoft.onedrive.item.create")
      resource(:drive_item)
      verb(:create)
      data_classification(:personal_data)
      label("Create Microsoft OneDrive item")
      description("Create a new folder or file in Microsoft OneDrive.")
      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.CreateItem)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@files_read_write], resolver: @scope_resolver)
      end

      input do
        field(:parent_id, :string)
        field(:name, :string, required?: true)
        field(:type, :string, default: "folder")
      end

      output do
        field(:item, :map)
      end
    end

    action :update_item do
      id("microsoft.onedrive.item.update")
      resource(:drive_item)
      verb(:update)
      data_classification(:personal_data)
      label("Update Microsoft OneDrive item")
      description("Update an existing Microsoft OneDrive drive item's metadata.")
      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.UpdateItem)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@files_read_write], resolver: @scope_resolver)
      end

      input do
        field(:item_id, :string, required?: true, example: "01ABCD1234...")
        field(:name, :string)
      end

      output do
        field(:item, :map)
      end
    end

    action :upload_item do
      id("microsoft.onedrive.item.upload")
      resource(:drive_item)
      verb(:create)
      data_classification(:personal_data)
      label("Upload Microsoft OneDrive file")
      description("Upload or replace a file in Microsoft OneDrive.")
      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.UploadItem)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@files_read_write], resolver: @scope_resolver)
      end

      input do
        field(:parent_id, :string)
        field(:name, :string, required?: true)
        field(:content, :string)
      end

      output do
        field(:item, :map)
      end
    end
  end
end
