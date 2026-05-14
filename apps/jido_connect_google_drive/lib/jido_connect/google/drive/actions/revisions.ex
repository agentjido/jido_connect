defmodule Jido.Connect.Google.Drive.Actions.Revisions do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  alias Jido.Connect.Google.Drive.Fields

  @metadata_scope "https://www.googleapis.com/auth/drive.metadata.readonly"
  @file_scope "https://www.googleapis.com/auth/drive.file"
  @scope_resolver Jido.Connect.Google.Drive.ScopeResolver
  @auth_profiles [:user, :service_account, :domain_delegated_service_account]

  actions do
    action :list_revisions do
      id("google.drive.revisions.list")
      resource(:revision)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List file revisions")
      description("List Google Drive revision metadata for a file.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.ListRevisions)
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
          description: "Google Drive revisions.list fields expression.",
          metadata: %{presets: Fields.revision_list_presets()}
        )
      end

      output do
        field(:revisions, {:array, :map})
        field(:next_page_token, :string)
      end
    end

    action :get_revision do
      id("google.drive.revision.get")
      resource(:revision)
      verb(:get)
      data_classification(:workspace_metadata)
      label("Get file revision")
      description("Fetch Google Drive revision metadata by file id and revision id.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.GetRevision)
      effect(:read)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:revision_id, :string, required?: true, example: "123")

        field(:fields, :string,
          description: "Google Drive revisions.get fields expression.",
          metadata: %{presets: Fields.revision_presets()}
        )

        field(:acknowledge_abuse, :boolean, default: false)
      end

      output do
        field(:revision, :map)
      end
    end

    action :update_revision do
      id("google.drive.revision.update")
      resource(:revision)
      verb(:update)
      data_classification(:workspace_metadata)
      label("Update file revision")
      description("Update Google Drive revision metadata such as keep-forever or publish state.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.UpdateRevision)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@file_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:revision_id, :string, required?: true, example: "123")
        field(:keep_forever, :boolean)
        field(:published, :boolean)
        field(:publish_auto, :boolean)
        field(:published_outside_domain, :boolean)

        field(:fields, :string,
          description: "Google Drive revisions.update fields expression.",
          metadata: %{presets: Fields.revision_presets()}
        )
      end

      output do
        field(:revision, :map)
      end
    end

    action :delete_revision do
      id("google.drive.revision.delete")
      resource(:revision)
      verb(:delete)
      data_classification(:workspace_metadata)
      label("Delete file revision")

      description(
        "Permanently delete a Google Drive binary-file revision when the provider allows it."
      )

      handler(Jido.Connect.Google.Drive.Handlers.Actions.DeleteRevision)
      effect(:destructive, confirmation: :always)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@file_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:revision_id, :string, required?: true, example: "123")
      end

      output do
        field(:result, :map)
      end
    end
  end
end
