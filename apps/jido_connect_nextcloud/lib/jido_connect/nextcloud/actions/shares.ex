defmodule Jido.Connect.Nextcloud.Actions.Shares do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Nextcloud.ScopeResolver

  actions do
    action :list_shares do
      id("nextcloud.shares.list")
      resource(:share)
      verb(:list)
      data_classification(:personal_data)
      label("List Nextcloud shares")
      description("List Nextcloud shares or shares for a specific file/folder path.")
      handler(Jido.Connect.Nextcloud.Handlers.Actions.ListShares)
      effect(:read)

      access do
        auth(:app_password)
        policies([:nextcloud_instance_access])
        scopes(["files:share"], resolver: @scope_resolver)
      end

      input do
        field(:path, :string)
        field(:reshares, :boolean, default: false)
        field(:subfiles, :boolean, default: false)
      end

      output do
        field(:shares, {:array, :map})
      end
    end

    action :get_share do
      id("nextcloud.share.get")
      resource(:share)
      verb(:get)
      data_classification(:personal_data)
      label("Get Nextcloud share")
      description("Fetch a Nextcloud share by id.")
      handler(Jido.Connect.Nextcloud.Handlers.Actions.GetShare)
      effect(:read)

      access do
        auth(:app_password)
        policies([:nextcloud_instance_access])
        scopes(["files:share"], resolver: @scope_resolver)
      end

      input do
        field(:share_id, :string, required?: true)
      end

      output do
        field(:share, :map)
      end
    end

    action :create_share do
      id("nextcloud.share.create")
      resource(:share)
      verb(:share)
      data_classification(:personal_data)
      label("Create Nextcloud share")
      description("Create a file/folder share through the Nextcloud OCS Share API.")
      handler(Jido.Connect.Nextcloud.Handlers.Actions.CreateShare)
      effect(:external_write, confirmation: :always)

      access do
        auth(:app_password)
        policies([:nextcloud_instance_access])
        scopes(["files:share"], resolver: @scope_resolver)
      end

      input do
        field(:path, :string, required?: true)
        field(:share_type, :integer, required?: true, example: 3)
        field(:share_with, :string)
        field(:permissions, :integer, default: 1)
        field(:password, :string)
        field(:expire_date, :string)
        field(:note, :string)
        field(:label, :string)
        field(:public_upload, :boolean, default: false)
        field(:send_mail, :boolean, default: false)
      end

      output do
        field(:share, :map)
      end
    end

    action :update_share do
      id("nextcloud.share.update")
      resource(:share)
      verb(:update)
      data_classification(:personal_data)
      label("Update Nextcloud share")
      description("Update a Nextcloud share through the OCS Share API.")
      handler(Jido.Connect.Nextcloud.Handlers.Actions.UpdateShare)
      effect(:external_write, confirmation: :always)

      access do
        auth(:app_password)
        policies([:nextcloud_instance_access])
        scopes(["files:share"], resolver: @scope_resolver)
      end

      input do
        field(:share_id, :string, required?: true)
        field(:permissions, :integer)
        field(:password, :string)
        field(:expire_date, :string)
        field(:note, :string)
        field(:label, :string)
        field(:public_upload, :boolean)
        field(:send_mail, :boolean)
      end

      output do
        field(:share, :map)
      end
    end

    action :delete_share do
      id("nextcloud.share.delete")
      resource(:share)
      verb(:delete)
      data_classification(:personal_data)
      label("Delete Nextcloud share")
      description("Delete a Nextcloud share through the OCS Share API.")
      handler(Jido.Connect.Nextcloud.Handlers.Actions.DeleteShare)
      effect(:destructive, confirmation: :always)

      access do
        auth(:app_password)
        policies([:nextcloud_instance_access])
        scopes(["files:share"], resolver: @scope_resolver)
      end

      input do
        field(:share_id, :string, required?: true)
      end

      output do
        field(:deleted, :boolean)
        field(:share_id, :string)
      end
    end

    action :search_sharees do
      id("nextcloud.sharees.search")
      resource(:sharee)
      verb(:list)
      data_classification(:personal_data)
      label("Search Nextcloud sharees")
      description("Search users, groups, emails, or other share recipients for sharing.")
      handler(Jido.Connect.Nextcloud.Handlers.Actions.SearchSharees)
      effect(:read)

      access do
        auth(:app_password)
        policies([:nextcloud_instance_access])
        scopes(["files:share"], resolver: @scope_resolver)
      end

      input do
        field(:search, :string, required?: true)
        field(:item_type, :string, default: "file")
        field(:per_page, :integer, default: 25)
        field(:lookup, :boolean, default: false)
      end

      output do
        field(:sharees, {:array, :map})
      end
    end
  end
end
