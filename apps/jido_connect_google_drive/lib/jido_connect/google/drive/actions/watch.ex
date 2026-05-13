defmodule Jido.Connect.Google.Drive.Actions.Watch do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @metadata_scope "https://www.googleapis.com/auth/drive.metadata.readonly"
  @scope_resolver Jido.Connect.Google.Drive.ScopeResolver

  actions do
    action :watch_file do
      id("google.drive.file.watch")
      resource(:channel)
      verb(:create)
      data_classification(:workspace_metadata)
      label("Watch file changes")
      description("Create a Google Drive push notification channel for one file.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.WatchFile)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:channel_id, :string, required?: true)
        field(:address, :string, required?: true, example: "https://example.com/webhooks/drive")
        field(:type, :string, default: "web_hook", enum: ["web_hook", "webhook"])
        field(:token, :string)
        field(:expiration, :string)
        field(:payload, :boolean)
        field(:params, :map)
        field(:supports_all_drives, :boolean, default: false)
        field(:acknowledge_abuse, :boolean, default: false)
        field(:include_permissions_for_view, :string)
        field(:include_labels, :string)
      end

      output do
        field(:channel, :map)
      end
    end

    action :watch_changes do
      id("google.drive.changes.watch")
      resource(:channel)
      verb(:create)
      data_classification(:workspace_metadata)
      label("Watch Drive changes")
      description("Create a Google Drive push notification channel for the change log.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.WatchChanges)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:page_token, :string, required?: true)
        field(:channel_id, :string, required?: true)
        field(:address, :string, required?: true, example: "https://example.com/webhooks/drive")
        field(:type, :string, default: "web_hook", enum: ["web_hook", "webhook"])
        field(:token, :string)
        field(:expiration, :string)
        field(:payload, :boolean)
        field(:params, :map)
        field(:page_size, :integer)
        field(:spaces, :string, default: "drive")
        field(:drive_id, :string)
        field(:include_corpus_removals, :boolean)
        field(:include_items_from_all_drives, :boolean, default: false)
        field(:include_removed, :boolean, default: true)
        field(:restrict_to_my_drive, :boolean, default: false)
        field(:supports_all_drives, :boolean, default: false)
        field(:include_permissions_for_view, :string)
        field(:include_labels, :string)
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
      label("Stop Drive notification channel")
      description("Stop a Google Drive push notification channel.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.StopChannel)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:user)
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
