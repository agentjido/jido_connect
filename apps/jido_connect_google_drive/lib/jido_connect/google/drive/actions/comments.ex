defmodule Jido.Connect.Google.Drive.Actions.Comments do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  alias Jido.Connect.Google.Drive.Fields

  @readonly_scope "https://www.googleapis.com/auth/drive.readonly"
  @file_scope "https://www.googleapis.com/auth/drive.file"
  @scope_resolver Jido.Connect.Google.Drive.ScopeResolver
  @auth_profiles [:user, :service_account, :domain_delegated_service_account]

  actions do
    action :list_comments do
      id("google.drive.comments.list")
      resource(:comment)
      verb(:list)
      data_classification(:workspace_content)
      label("List file comments")
      description("List Google Drive comments for a file.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.ListComments)
      effect(:read)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:include_deleted, :boolean, default: false)
        field(:page_size, :integer, default: 100)
        field(:page_token, :string)
        field(:start_modified_time, :string)

        field(:fields, :string,
          description: "Google Drive comments.list fields expression.",
          metadata: %{presets: Fields.comment_list_presets()}
        )
      end

      output do
        field(:comments, {:array, :map})
        field(:next_page_token, :string)
      end
    end

    action :get_comment do
      id("google.drive.comment.get")
      resource(:comment)
      verb(:get)
      data_classification(:workspace_content)
      label("Get file comment")
      description("Fetch a Google Drive comment by file id and comment id.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.GetComment)
      effect(:read)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:comment_id, :string, required?: true, example: "comment123")
        field(:include_deleted, :boolean, default: false)

        field(:fields, :string,
          description: "Google Drive comments.get fields expression.",
          metadata: %{presets: Fields.comment_presets()}
        )
      end

      output do
        field(:comment, :map)
      end
    end

    action :create_comment do
      id("google.drive.comment.create")
      resource(:comment)
      verb(:create)
      data_classification(:workspace_content)
      label("Create file comment")
      description("Create a Google Drive comment on a file.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.CreateComment)
      effect(:external_write, confirmation: :always)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@file_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:content, :string, required?: true)
        field(:anchor, :string)
        field(:quoted_file_content, :map)

        field(:fields, :string,
          description: "Google Drive comments.create fields expression.",
          metadata: %{presets: Fields.comment_presets()}
        )
      end

      output do
        field(:comment, :map)
      end
    end

    action :update_comment do
      id("google.drive.comment.update")
      resource(:comment)
      verb(:update)
      data_classification(:workspace_content)
      label("Update file comment")
      description("Update a Google Drive comment's content.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.UpdateComment)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@file_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:comment_id, :string, required?: true, example: "comment123")
        field(:content, :string, required?: true)

        field(:fields, :string,
          description: "Google Drive comments.update fields expression.",
          metadata: %{presets: Fields.comment_presets()}
        )
      end

      output do
        field(:comment, :map)
      end
    end

    action :delete_comment do
      id("google.drive.comment.delete")
      resource(:comment)
      verb(:delete)
      data_classification(:workspace_content)
      label("Delete file comment")
      description("Delete a Google Drive comment from a file.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.DeleteComment)
      effect(:destructive, confirmation: :always)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@file_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:comment_id, :string, required?: true, example: "comment123")
      end

      output do
        field(:result, :map)
      end
    end
  end
end
