defmodule Jido.Connect.Google.Drive.Actions.Watch do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  alias Jido.Connect.Google.Drive.Fields

  @metadata_scope "https://www.googleapis.com/auth/drive.metadata.readonly"
  @scope_resolver Jido.Connect.Google.Drive.ScopeResolver
  @auth_profiles [:user, :service_account, :domain_delegated_service_account]
  @channel_types ["web_hook", "webhook"]

  actions do
    action :watch_changes do
      id("google.drive.changes.watch")
      resource(:change)
      verb(:watch)
      data_classification(:workspace_metadata)
      label("Watch Drive changes")
      description("Create or renew a Google Drive push notification channel for Drive changes.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.WatchChanges)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:page_token, :string,
          required?: true,
          description:
            "Start page token from google.drive.file.changed polling or changes.getStartPageToken."
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
      end
    end

    action :watch_file do
      id("google.drive.file.watch")
      resource(:file)
      verb(:watch)
      data_classification(:workspace_metadata)
      label("Watch Drive file")
      description("Create or renew a Google Drive push notification channel for a file.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.WatchFile)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")

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
        field(:acknowledge_abuse, :boolean, default: false)

        field(:include_permissions_for_view, :string,
          enum: Fields.permission_views(),
          example: "published"
        )

        field(:include_labels, :string)
        field(:supports_all_drives, :boolean, default: false)
      end

      output do
        field(:channel, :map)
      end
    end

    action :stop_channel do
      id("google.drive.channel.stop")
      resource(:channel)
      verb(:delete)
      data_classification(:workspace_metadata)
      label("Stop Drive channel")
      description("Stop Google Drive push notification delivery for a watched resource channel.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.StopChannel)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:channel_id, :string, required?: true)
        field(:resource_id, :string, required?: true)
      end

      output do
        field(:result, :map)
      end
    end
  end
end
