defmodule Jido.Connect.MicrosoftOnedrive.Actions.Destructive do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @files_read_write "Files.ReadWrite"
  @scope_resolver Jido.Connect.MicrosoftOnedrive.ScopeResolver

  actions do
    action :delete_item do
      id("microsoft.onedrive.item.delete")
      resource(:drive_item)
      verb(:delete)
      data_classification(:personal_data)
      label("Delete Microsoft OneDrive item")
      description("Permanently delete a Microsoft OneDrive drive item.")
      handler(Jido.Connect.MicrosoftOnedrive.Handlers.Actions.DeleteItem)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@files_read_write], resolver: @scope_resolver)
      end

      input do
        field(:item_id, :string, required?: true, example: "01ABCD1234...")
      end

      output do
        field(:deleted, :boolean)
        field(:item_id, :string)
      end
    end
  end
end
