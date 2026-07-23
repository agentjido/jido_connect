defmodule Jido.Connect.Google.Drive do
  @moduledoc """
  Google Drive integration authored with the `Jido.Connect` Spark DSL.
  """

  use Jido.Connect,
    fragments: [
      Jido.Connect.Google.Drive.Actions.About,
      Jido.Connect.Google.Drive.Actions.Read,
      Jido.Connect.Google.Drive.Actions.Write,
      Jido.Connect.Google.Drive.Actions.FileContent,
      Jido.Connect.Google.Drive.Actions.Permissions,
      Jido.Connect.Google.Drive.Actions.Revisions,
      Jido.Connect.Google.Drive.Actions.Comments,
      Jido.Connect.Google.Drive.Actions.Replies,
      Jido.Connect.Google.Drive.Actions.SharedDrives,
      Jido.Connect.Google.Drive.Actions.Changes,
      Jido.Connect.Google.Drive.Actions.Collections,
      Jido.Connect.Google.Drive.Actions.Watch,
      Jido.Connect.Google.Drive.Triggers.Changes
    ]

  integration do
    id(:google_drive)
    name("Google Drive")
    description("Google Drive file, folder, permission, export, and change tools.")
    category(:productivity)
    docs(["https://developers.google.com/drive/api/guides/about-sdk"])
  end

  catalog do
    package(:jido_connect_google_drive)
    status(:available)
    tags([:google, :workspace, :files, :productivity])

    capability :watch_collection do
      kind(:runtime)
      feature(:watch_collection)
      label("Watch collections")

      description(
        "Create Drive change-log watchers for the user or an associated folder and return reusable cursors."
      )

      metadata(%{
        generic_capability: :watch_collection,
        tool_id: "google.drive.collection.watch",
        checkpoint_field: :checkpoint,
        provider_mapping: %{watch_collection: "changes.getStartPageToken + changes.watch"}
      })
    end

    capability :list_collection_changes do
      kind(:runtime)
      feature(:list_collection_changes)
      label("List collection changes")

      description(
        "Consume Drive change checkpoints and return provider-neutral signals, optionally classified for a folder."
      )

      metadata(%{
        generic_capability: :list_collection_changes,
        tool_id: "google.drive.collection.changes.list",
        checkpoint_field: :checkpoint,
        signal_shape: :collection_change,
        provider_mapping: %{list_collection_changes: "changes.list"}
      })
    end

    capability :collection_changes do
      kind(:poll)
      feature(:collection_changes)
      label("Collection changes")

      description("Poll provider-neutral Drive collection changes with opaque checkpoints.")

      metadata(%{
        generic_capability: :collection_changes,
        trigger_id: "google.drive.collection.changes",
        checkpoint_field: :checkpoint,
        signal_shape: :collection_change
      })
    end

    capability :collection_changes_push do
      kind(:webhook)
      feature(:collection_changes_push)
      label("Collection changes push")

      description(
        "Receive lightweight Drive push notifications for user or collection change refreshes."
      )

      metadata(%{
        generic_capability: :collection_changes_push,
        trigger_id: "google.drive.collection.changes.push",
        follow_up_capability: :list_collection_changes,
        checkpoint_field: :checkpoint,
        signal_shape: :collection_change_available
      })
    end
  end

  auth do
    oauth2 :user do
      default?(true)
      owner(:app_user)
      subject(:user)
      label("Google OAuth user")
      authorize_url("https://accounts.google.com/o/oauth2/v2/auth")
      token_url("https://oauth2.googleapis.com/token")
      callback_path("/integrations/google/oauth/callback")
      token_field(:access_token)
      refresh_token_field(:refresh_token)
      setup :oauth2_authorization_code
      credential_fields([:access_token, :refresh_token])
      lease_fields([:access_token])

      scopes(
        Jido.Connect.Google.Scopes.user_default() ++
          Jido.Connect.Google.Scopes.product(:drive)
      )

      default_scopes(Jido.Connect.Google.Scopes.user_default())
      optional_scopes(Jido.Connect.Google.Scopes.product(:drive))
      pkce?(true)
      refresh?(true)
      revoke?(true)
    end

    service_account :service_account do
      owner(:system)
      subject(:service_account)
      label("Google service account")
      setup(:google_service_account_jwt)
      credential_fields([:client_email, :private_key, :private_key_id])
      lease_fields([:access_token])
      scopes(Jido.Connect.Google.Scopes.product(:drive))
      default_scopes([])
      optional_scopes(Jido.Connect.Google.Scopes.product(:drive))
    end

    domain_delegated_service_account :domain_delegated_service_account do
      owner(:tenant)
      subject(:workspace_user)
      label("Google domain-delegated service account")
      setup(:google_domain_wide_delegation)
      credential_fields([:client_email, :private_key, :private_key_id, :subject])
      lease_fields([:access_token])
      scopes(Jido.Connect.Google.Scopes.product(:drive))
      default_scopes([])
      optional_scopes(Jido.Connect.Google.Scopes.product(:drive))
    end
  end

  defdelegate catalog_packs, to: Jido.Connect.Google.Drive.CatalogPacks, as: :all
  defdelegate readonly_pack, to: Jido.Connect.Google.Drive.CatalogPacks, as: :readonly
  defdelegate file_writer_pack, to: Jido.Connect.Google.Drive.CatalogPacks, as: :file_writer
  defdelegate watch_pack, to: Jido.Connect.Google.Drive.CatalogPacks, as: :watch
end
