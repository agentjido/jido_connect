defmodule Jido.Connect.Gmail.Actions.Write do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @send_scope "https://www.googleapis.com/auth/gmail.send"
  @compose_scope "https://www.googleapis.com/auth/gmail.compose"
  @labels_scope "https://www.googleapis.com/auth/gmail.labels"
  @modify_scope "https://www.googleapis.com/auth/gmail.modify"
  @mail_scope "https://mail.google.com/"
  @scope_resolver Jido.Connect.Gmail.ScopeResolver

  actions do
    action :send_message do
      id("google.gmail.message.send")
      resource(:message)
      verb(:send)
      data_classification(:message_content)
      label("Send Gmail message")
      description("Send an email through Gmail after validating recipients and body content.")
      handler(Jido.Connect.Gmail.Handlers.Actions.SendMessage)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@send_scope], resolver: @scope_resolver)
      end

      input do
        field(:to, {:array, :string}, required?: true)
        field(:cc, {:array, :string}, default: [])
        field(:bcc, {:array, :string}, default: [])
        field(:subject, :string, required?: true)
        field(:body_text, :string)
        field(:body_html, :string)
        field(:thread_id, :string)
        field(:in_reply_to, :string)
        field(:references, :string)
      end

      output do
        field(:message, :map)
      end
    end

    action :create_draft do
      id("google.gmail.draft.create")
      resource(:draft)
      verb(:create)
      data_classification(:message_content)
      label("Create Gmail draft")
      description("Create a Gmail draft after validating recipients and body content.")
      handler(Jido.Connect.Gmail.Handlers.Actions.CreateDraft)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@compose_scope], resolver: @scope_resolver)
      end

      input do
        field(:to, {:array, :string}, required?: true)
        field(:cc, {:array, :string}, default: [])
        field(:bcc, {:array, :string}, default: [])
        field(:subject, :string, required?: true)
        field(:body_text, :string)
        field(:body_html, :string)
        field(:thread_id, :string)
        field(:in_reply_to, :string)
        field(:references, :string)
      end

      output do
        field(:draft, :map)
      end
    end

    action :update_draft do
      id("google.gmail.draft.update")
      resource(:draft)
      verb(:update)
      data_classification(:message_content)
      label("Update Gmail draft")
      description("Replace a Gmail draft after validating recipients and body content.")
      handler(Jido.Connect.Gmail.Handlers.Actions.UpdateDraft)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@compose_scope], resolver: @scope_resolver)
      end

      input do
        field(:draft_id, :string, required?: true, example: "r123...")
        field(:to, {:array, :string}, required?: true)
        field(:cc, {:array, :string}, default: [])
        field(:bcc, {:array, :string}, default: [])
        field(:subject, :string, required?: true)
        field(:body_text, :string)
        field(:body_html, :string)
        field(:thread_id, :string)
        field(:in_reply_to, :string)
        field(:references, :string)
      end

      output do
        field(:draft, :map)
      end
    end

    action :send_draft do
      id("google.gmail.draft.send")
      resource(:draft)
      verb(:send)
      data_classification(:message_content)
      label("Send Gmail draft")
      description("Send an existing Gmail draft.")
      handler(Jido.Connect.Gmail.Handlers.Actions.SendDraft)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@compose_scope], resolver: @scope_resolver)
      end

      input do
        field(:draft_id, :string, required?: true, example: "r123...")
      end

      output do
        field(:message, :map)
      end
    end

    action :delete_draft do
      id("google.gmail.draft.delete")
      resource(:draft)
      verb(:delete)
      data_classification(:message_content)
      label("Delete Gmail draft")
      description("Delete an existing Gmail draft without sending it.")
      handler(Jido.Connect.Gmail.Handlers.Actions.DeleteDraft)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@compose_scope], resolver: @scope_resolver)
      end

      input do
        field(:draft_id, :string, required?: true, example: "r123...")
      end

      output do
        field(:result, :map)
      end
    end

    action :create_label do
      id("google.gmail.label.create")
      resource(:label)
      verb(:create)
      data_classification(:personal_data)
      label("Create Gmail label")
      description("Create a Gmail user label.")
      handler(Jido.Connect.Gmail.Handlers.Actions.CreateLabel)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@labels_scope], resolver: @scope_resolver)
      end

      input do
        field(:name, :string, required?: true, example: "Customers")
        field(:message_list_visibility, :string, enum: ["show", "hide"])

        field(:label_list_visibility, :string,
          enum: ["labelShow", "labelShowIfUnread", "labelHide"]
        )

        field(:color, :map)
      end

      output do
        field(:label, :map)
      end
    end

    action :update_label do
      id("google.gmail.label.update")
      resource(:label)
      verb(:update)
      data_classification(:personal_data)
      label("Update Gmail label")
      description("Update mutable Gmail user-label fields.")
      handler(Jido.Connect.Gmail.Handlers.Actions.UpdateLabel)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@labels_scope], resolver: @scope_resolver)
      end

      input do
        field(:label_id, :string, required?: true, example: "Label_123")
        field(:name, :string)
        field(:message_list_visibility, :string, enum: ["show", "hide"])

        field(:label_list_visibility, :string,
          enum: ["labelShow", "labelShowIfUnread", "labelHide"]
        )

        field(:color, :map)
      end

      output do
        field(:label, :map)
      end
    end

    action :delete_label do
      id("google.gmail.label.delete")
      resource(:label)
      verb(:delete)
      data_classification(:personal_data)
      label("Delete Gmail label")
      description("Delete a Gmail user label definition.")
      handler(Jido.Connect.Gmail.Handlers.Actions.DeleteLabel)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@labels_scope], resolver: @scope_resolver)
      end

      input do
        field(:label_id, :string, required?: true, example: "Label_123")
      end

      output do
        field(:result, :map)
      end
    end

    action :apply_message_labels do
      id("google.gmail.message.labels.apply")
      resource(:message)
      verb(:update)
      data_classification(:message_content)
      label("Apply Gmail message labels")
      description("Add or remove labels on a Gmail message.")
      handler(Jido.Connect.Gmail.Handlers.Actions.ApplyMessageLabels)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@modify_scope], resolver: @scope_resolver)
      end

      input do
        field(:message_id, :string, required?: true, example: "18c...")
        field(:add_label_ids, {:array, :string}, default: [])
        field(:remove_label_ids, {:array, :string}, default: [])
      end

      output do
        field(:message, :map)
      end
    end

    action :batch_modify_messages do
      id("google.gmail.messages.batch_modify")
      resource(:message)
      verb(:update)
      data_classification(:message_content)
      label("Batch modify Gmail messages")
      description("Add or remove labels on a batch of Gmail messages.")
      handler(Jido.Connect.Gmail.Handlers.Actions.BatchModifyMessages)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@modify_scope], resolver: @scope_resolver)
      end

      input do
        field(:message_ids, {:array, :string}, required?: true)
        field(:add_label_ids, {:array, :string}, default: [])
        field(:remove_label_ids, {:array, :string}, default: [])
      end

      output do
        field(:result, :map)
      end
    end

    action :trash_message do
      id("google.gmail.message.trash")
      resource(:message)
      verb(:update)
      data_classification(:message_content)
      label("Trash Gmail message")
      description("Move a Gmail message to Trash.")
      handler(Jido.Connect.Gmail.Handlers.Actions.TrashMessage)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@modify_scope], resolver: @scope_resolver)
      end

      input do
        field(:message_id, :string, required?: true, example: "18c...")
      end

      output do
        field(:message, :map)
      end
    end

    action :untrash_message do
      id("google.gmail.message.untrash")
      resource(:message)
      verb(:update)
      data_classification(:message_content)
      label("Untrash Gmail message")
      description("Remove a Gmail message from Trash.")
      handler(Jido.Connect.Gmail.Handlers.Actions.UntrashMessage)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@modify_scope], resolver: @scope_resolver)
      end

      input do
        field(:message_id, :string, required?: true, example: "18c...")
      end

      output do
        field(:message, :map)
      end
    end

    action :delete_message do
      id("google.gmail.message.delete")
      resource(:message)
      verb(:delete)
      data_classification(:message_content)
      label("Delete Gmail message")
      description("Immediately and permanently delete a Gmail message, bypassing Trash.")
      handler(Jido.Connect.Gmail.Handlers.Actions.DeleteMessage)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@mail_scope], resolver: @scope_resolver)
      end

      input do
        field(:message_id, :string, required?: true, example: "18c...")
      end

      output do
        field(:result, :map)
      end
    end

    action :batch_delete_messages do
      id("google.gmail.messages.batch_delete")
      resource(:message)
      verb(:delete)
      data_classification(:message_content)
      label("Batch delete Gmail messages")
      description("Immediately and permanently delete Gmail messages, bypassing Trash.")
      handler(Jido.Connect.Gmail.Handlers.Actions.BatchDeleteMessages)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@mail_scope], resolver: @scope_resolver)
      end

      input do
        field(:message_ids, {:array, :string}, required?: true)
      end

      output do
        field(:result, :map)
      end
    end

    action :modify_thread do
      id("google.gmail.thread.modify")
      resource(:thread)
      verb(:update)
      data_classification(:message_content)
      label("Modify Gmail thread")
      description("Add or remove labels on every message in a Gmail thread.")
      handler(Jido.Connect.Gmail.Handlers.Actions.ModifyThread)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@modify_scope], resolver: @scope_resolver)
      end

      input do
        field(:thread_id, :string, required?: true, example: "18c...")
        field(:add_label_ids, {:array, :string}, default: [])
        field(:remove_label_ids, {:array, :string}, default: [])
      end

      output do
        field(:thread, :map)
      end
    end

    action :trash_thread do
      id("google.gmail.thread.trash")
      resource(:thread)
      verb(:update)
      data_classification(:message_content)
      label("Trash Gmail thread")
      description("Move a Gmail thread and its messages to Trash.")
      handler(Jido.Connect.Gmail.Handlers.Actions.TrashThread)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@modify_scope], resolver: @scope_resolver)
      end

      input do
        field(:thread_id, :string, required?: true, example: "18c...")
      end

      output do
        field(:thread, :map)
      end
    end

    action :untrash_thread do
      id("google.gmail.thread.untrash")
      resource(:thread)
      verb(:update)
      data_classification(:message_content)
      label("Untrash Gmail thread")
      description("Remove a Gmail thread and its messages from Trash.")
      handler(Jido.Connect.Gmail.Handlers.Actions.UntrashThread)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@modify_scope], resolver: @scope_resolver)
      end

      input do
        field(:thread_id, :string, required?: true, example: "18c...")
      end

      output do
        field(:thread, :map)
      end
    end

    action :delete_thread do
      id("google.gmail.thread.delete")
      resource(:thread)
      verb(:delete)
      data_classification(:message_content)
      label("Delete Gmail thread")
      description("Immediately and permanently delete a Gmail thread and its messages.")
      handler(Jido.Connect.Gmail.Handlers.Actions.DeleteThread)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@mail_scope], resolver: @scope_resolver)
      end

      input do
        field(:thread_id, :string, required?: true, example: "18c...")
      end

      output do
        field(:result, :map)
      end
    end
  end
end
