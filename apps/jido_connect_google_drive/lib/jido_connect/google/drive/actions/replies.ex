defmodule Jido.Connect.Google.Drive.Actions.Replies do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  alias Jido.Connect.Google.Drive.Fields

  @readonly_scope "https://www.googleapis.com/auth/drive.readonly"
  @file_scope "https://www.googleapis.com/auth/drive.file"
  @scope_resolver Jido.Connect.Google.Drive.ScopeResolver
  @auth_profiles [:user, :service_account, :domain_delegated_service_account]
  @reply_actions ["resolve", "reopen"]

  actions do
    action :list_replies do
      id("google.drive.replies.list")
      resource(:reply)
      verb(:list)
      data_classification(:workspace_content)
      label("List comment replies")
      description("List Google Drive replies for a file comment.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.ListReplies)
      effect(:read)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:comment_id, :string, required?: true, example: "comment123")
        field(:include_deleted, :boolean, default: false)
        field(:page_size, :integer, default: 100)
        field(:page_token, :string)

        field(:fields, :string,
          description: "Google Drive replies.list fields expression.",
          metadata: %{presets: Fields.reply_list_presets()}
        )
      end

      output do
        field(:replies, {:array, :map})
        field(:next_page_token, :string)
      end
    end

    action :get_reply do
      id("google.drive.reply.get")
      resource(:reply)
      verb(:get)
      data_classification(:workspace_content)
      label("Get comment reply")
      description("Fetch a Google Drive comment reply by file, comment, and reply id.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.GetReply)
      effect(:read)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:comment_id, :string, required?: true, example: "comment123")
        field(:reply_id, :string, required?: true, example: "reply123")
        field(:include_deleted, :boolean, default: false)

        field(:fields, :string,
          description: "Google Drive replies.get fields expression.",
          metadata: %{presets: Fields.reply_presets()}
        )
      end

      output do
        field(:reply, :map)
      end
    end

    action :create_reply do
      id("google.drive.reply.create")
      resource(:reply)
      verb(:create)
      data_classification(:workspace_content)
      label("Create comment reply")
      description("Create a Google Drive reply on a file comment.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.CreateReply)
      effect(:external_write, confirmation: :always)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@file_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:comment_id, :string, required?: true, example: "comment123")
        field(:content, :string)
        field(:action, :string, enum: @reply_actions)

        field(:fields, :string,
          description: "Google Drive replies.create fields expression.",
          metadata: %{presets: Fields.reply_presets()}
        )
      end

      output do
        field(:reply, :map)
      end
    end

    action :update_reply do
      id("google.drive.reply.update")
      resource(:reply)
      verb(:update)
      data_classification(:workspace_content)
      label("Update comment reply")
      description("Update a Google Drive comment reply's content.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.UpdateReply)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@file_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:comment_id, :string, required?: true, example: "comment123")
        field(:reply_id, :string, required?: true, example: "reply123")
        field(:content, :string, required?: true)

        field(:fields, :string,
          description: "Google Drive replies.update fields expression.",
          metadata: %{presets: Fields.reply_presets()}
        )
      end

      output do
        field(:reply, :map)
      end
    end

    action :delete_reply do
      id("google.drive.reply.delete")
      resource(:reply)
      verb(:delete)
      data_classification(:workspace_content)
      label("Delete comment reply")
      description("Delete a Google Drive reply from a file comment.")
      handler(Jido.Connect.Google.Drive.Handlers.Actions.DeleteReply)
      effect(:destructive, confirmation: :always)

      access do
        auth(@auth_profiles, default: :user)
        scopes([@file_scope], resolver: @scope_resolver)
      end

      input do
        field(:file_id, :string, required?: true, example: "1abc...")
        field(:comment_id, :string, required?: true, example: "comment123")
        field(:reply_id, :string, required?: true, example: "reply123")
      end

      output do
        field(:result, :map)
      end
    end
  end
end
