defmodule Jido.Connect.Google.Drive.Actions.Revisions do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @metadata_scope "https://www.googleapis.com/auth/drive.metadata.readonly"
  @scope_resolver Jido.Connect.Google.Drive.ScopeResolver

  actions do
    action :list_revisions do
      id("google.drive.revisions.list")
      resource(:revision)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List file revisions")
      description("List Google Drive revisions for a file.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.ListRevisions)
      effect(:read)

      access do
        auth(:user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:page_size, :integer, default: 100)
        field(:page_token, :string)
        field(:fields, :string)
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
        auth(:user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:revision_id, :string, required?: true, example: "123")
        field(:fields, :string)
        field(:acknowledge_abuse, :boolean, default: false)
      end

      output do
        field(:revision, :map)
      end
    end
  end
end
