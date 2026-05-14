defmodule Jido.Connect.Gmail.Actions.Read do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @metadata_scope "https://www.googleapis.com/auth/gmail.metadata"
  @scope_resolver Jido.Connect.Gmail.ScopeResolver

  actions do
    action :get_profile do
      id("google.gmail.profile.get")
      resource(:profile)
      verb(:get)
      data_classification(:personal_data)
      label("Get Gmail profile")
      description("Fetch Gmail mailbox profile metadata for the authenticated user.")
      handler(Jido.Connect.Gmail.Handlers.Actions.GetProfile)
      effect(:read)

      access do
        auth(:user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
      end

      output do
        field(:profile, :map)
      end
    end

    action :list_labels do
      id("google.gmail.labels.list")
      resource(:label)
      verb(:list)
      data_classification(:personal_data)
      label("List Gmail labels")
      description("List Gmail labels for the authenticated user.")
      handler(Jido.Connect.Gmail.Handlers.Actions.ListLabels)
      effect(:read)

      access do
        auth(:user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
      end

      output do
        field(:labels, {:array, :map})
      end
    end

    action :list_messages do
      id("google.gmail.messages.list")
      resource(:message)
      verb(:list)
      data_classification(:message_content)
      label("List Gmail messages")
      description("List Gmail message metadata summaries without fetching full message bodies.")
      handler(Jido.Connect.Gmail.Handlers.Actions.ListMessages)
      effect(:read)

      access do
        auth(:user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:query, :string)
        field(:label_ids, {:array, :string}, default: [])
        field(:page_size, :integer, default: 25)
        field(:page_token, :string)
        field(:include_spam_trash, :boolean, default: false)
      end

      output do
        field(:messages, {:array, :map})
        field(:next_page_token, :string)
        field(:result_size_estimate, :integer)
      end
    end

    action :get_message do
      id("google.gmail.message.get")
      resource(:message)
      verb(:get)
      data_classification(:message_content)
      label("Get Gmail message metadata")
      description("Fetch Gmail message metadata with optional header allowlist and no body data.")
      handler(Jido.Connect.Gmail.Handlers.Actions.GetMessage)
      effect(:read)

      access do
        auth(:user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:message_id, :string, required?: true, example: "18c...")
        field(:metadata_headers, {:array, :string}, default: [])
      end

      output do
        field(:message, :map)
      end
    end

    action :list_threads do
      id("google.gmail.threads.list")
      resource(:thread)
      verb(:list)
      data_classification(:message_content)
      label("List Gmail threads")
      description("List Gmail thread metadata summaries without fetching full message bodies.")
      handler(Jido.Connect.Gmail.Handlers.Actions.ListThreads)
      effect(:read)

      access do
        auth(:user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:query, :string)
        field(:label_ids, {:array, :string}, default: [])
        field(:page_size, :integer, default: 25)
        field(:page_token, :string)
        field(:include_spam_trash, :boolean, default: false)
      end

      output do
        field(:threads, {:array, :map})
        field(:next_page_token, :string)
        field(:result_size_estimate, :integer)
      end
    end

    action :get_thread do
      id("google.gmail.thread.get")
      resource(:thread)
      verb(:get)
      data_classification(:message_content)
      label("Get Gmail thread metadata")
      description("Fetch Gmail thread metadata with optional header allowlist and no body data.")
      handler(Jido.Connect.Gmail.Handlers.Actions.GetThread)
      effect(:read)

      access do
        auth(:user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:thread_id, :string, required?: true, example: "18c...")
        field(:metadata_headers, {:array, :string}, default: [])
      end

      output do
        field(:thread, :map)
      end
    end

    action :list_history do
      id("google.gmail.history.list")
      resource(:history)
      verb(:list)
      data_classification(:message_content)
      label("List Gmail history")
      description("List Gmail mailbox history records from a starting history id.")
      handler(Jido.Connect.Gmail.Handlers.Actions.ListHistory)
      effect(:read)

      access do
        auth(:user)
        scopes([@metadata_scope], resolver: @scope_resolver)
      end

      input do
        field(:start_history_id, :string, required?: true, example: "123456")
        field(:label_id, :string)
        field(:history_types, {:array, :string}, default: [])
        field(:page_size, :integer, default: 100)
        field(:page_token, :string)
      end

      output do
        field(:history, {:array, :map})
        field(:next_page_token, :string)
        field(:history_id, :string)
      end
    end

    action :get_attachment do
      id("google.gmail.message.attachment.get")
      resource(:attachment)
      verb(:get)
      data_classification(:message_content)
      label("Get Gmail message attachment")
      description("Fetch base64url-encoded Gmail attachment data for a message attachment id.")
      handler(Jido.Connect.Gmail.Handlers.Actions.GetAttachment)
      effect(:read)

      access do
        auth(:user)
        scopes(["https://www.googleapis.com/auth/gmail.readonly"], resolver: @scope_resolver)
      end

      input do
        field(:message_id, :string, required?: true, example: "18c...")
        field(:attachment_id, :string, required?: true, example: "ANGjdJ...")
      end

      output do
        field(:attachment, :map)
      end
    end
  end
end
