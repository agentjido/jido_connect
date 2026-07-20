defmodule Jido.Connect.Google.Drive.Actions.Collections do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  alias Jido.Connect.Google.Drive.Fields

  @metadata_scope "https://www.googleapis.com/auth/drive.metadata.readonly"
  @scope_resolver Jido.Connect.Google.Drive.ScopeResolver
  @auth_profiles [:user, :service_account, :domain_delegated_service_account]
  @channel_types ["web_hook", "webhook"]

  actions do
    action :watch_collection do
      id("google.drive.collection.watch")
      resource(:collection)
      verb(:watch)
      data_classification(:workspace_metadata)
      label("Watch Drive collection")

      description(
        "Create a Google Drive changes watch channel for a folder-like collection and return a provider cursor."
      )

      handler(Jido.Connect.Google.Drive.Handlers.Actions.WatchCollection)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:collection_id, :string,
          required?: true,
          description:
            "Drive folder id to associate with this watch. Drive watches changes globally and filters during list_collection_changes."
        )

        field(:channel_id, :string,
          required?: true,
          description:
            "Unique channel id, usually a UUID, with a maximum length of 64 characters."
        )

        field(:address, :string,
          required?: true,
          description: "HTTPS webhook URL that receives Google Drive push notifications."
        )

        field(:channel_type, :string, default: "web_hook", enum: @channel_types)
        field(:token, :string, description: "Opaque channel token echoed in webhook headers.")
        field(:expiration_ms, :integer, description: "Requested Unix timestamp in milliseconds.")
        field(:payload, :boolean)
        field(:delivery_params, :map)
        field(:page_size, :integer, default: 100)
        field(:spaces, :string, default: "drive")
        field(:drive_id, :string)
        field(:include_corpus_removals, :boolean, default: false)
        field(:include_items_from_all_drives, :boolean, default: false)
        field(:include_removed, :boolean, default: true)
        field(:restrict_to_my_drive, :boolean, default: false)

        field(:include_permissions_for_view, :string,
          enum: Fields.permission_views(),
          example: "published"
        )

        field(:include_labels, :string)
        field(:supports_all_drives, :boolean, default: false)
      end

      output do
        field(:channel, :map)
        field(:checkpoint, :string)
        field(:collection_id, :string)
        field(:drive_id, :string)
        field(:provider, :string)
        field(:provider_resource, :string)
      end
    end

    action :list_collection_changes do
      id("google.drive.collection.changes.list")
      resource(:collection)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List Drive collection changes")

      description(
        "Consume a Drive changes checkpoint and return provider-neutral collection signals."
      )

      handler(Jido.Connect.Google.Drive.Handlers.Actions.ListCollectionChanges)
      effect(:read)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:checkpoint, :string,
          description:
            "Opaque provider checkpoint from google.drive.collection.watch or a previous collection changes response."
        )

        field(:cursor, :string, description: "Deprecated alias for checkpoint.")

        field(:collection_id, :string,
          required?: true,
          description: "Drive folder id used to filter relevant changes."
        )

        field(:page_size, :integer, default: 100)
        field(:spaces, :string, default: "drive")
        field(:drive_id, :string)
        field(:include_items_from_all_drives, :boolean, default: false)
        field(:include_removed, :boolean, default: true)
        field(:restrict_to_my_drive, :boolean, default: false)
        field(:supports_all_drives, :boolean, default: false)
      end

      output do
        field(:signals, {:array, :map})
        field(:checkpoint, :string)
        field(:has_more?, :boolean)
      end
    end
  end
end
