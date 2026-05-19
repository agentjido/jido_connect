defmodule Jido.Connect.MicrosoftOutlook.Actions.Write do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @mail_send "Mail.Send"
  @mail_read_write "Mail.ReadWrite"
  @scope_resolver Jido.Connect.MicrosoftOutlook.ScopeResolver

  actions do
    action :send_message do
      id("microsoft.outlook.message.send")
      resource(:message)
      verb(:create)
      data_classification(:message_content)
      label("Send Outlook Mail message")
      description("Send a new Outlook Mail message.")
      handler(Jido.Connect.MicrosoftOutlook.Handlers.Actions.SendMessage)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@mail_send], resolver: @scope_resolver)
      end

      input do
        field(:to, {:array, :string}, required?: true)
        field(:subject, :string, required?: true)
        field(:body, :string)
        field(:content_type, :string, default: "text")
        field(:cc, {:array, :string}, default: [])
        field(:bcc, {:array, :string}, default: [])
        field(:reply_to, {:array, :string}, default: [])
      end

      output do
        field(:message, :map)
      end
    end

    action :create_draft do
      id("microsoft.outlook.draft.create")
      resource(:draft)
      verb(:create)
      data_classification(:message_content)
      label("Create Outlook Mail draft")
      description("Create a new Outlook Mail draft message.")
      handler(Jido.Connect.MicrosoftOutlook.Handlers.Actions.CreateDraft)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@mail_send], resolver: @scope_resolver)
      end

      input do
        field(:to, {:array, :string}, default: [])
        field(:subject, :string)
        field(:body, :string)
        field(:content_type, :string, default: "text")
      end

      output do
        field(:draft, :map)
      end
    end

    action :update_draft do
      id("microsoft.outlook.draft.update")
      resource(:draft)
      verb(:update)
      data_classification(:message_content)
      label("Update Outlook Mail draft")
      description("Update an existing Outlook Mail draft message.")
      handler(Jido.Connect.MicrosoftOutlook.Handlers.Actions.UpdateDraft)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@mail_send], resolver: @scope_resolver)
      end

      input do
        field(:draft_id, :string, required?: true, example: "AAMkAGI2...")
        field(:to, {:array, :string})
        field(:subject, :string)
        field(:body, :string)
      end

      output do
        field(:draft, :map)
      end
    end

    action :send_draft do
      id("microsoft.outlook.draft.send")
      resource(:draft)
      verb(:create)
      data_classification(:message_content)
      label("Send Outlook Mail draft")
      description("Send an existing Outlook Mail draft message.")
      handler(Jido.Connect.MicrosoftOutlook.Handlers.Actions.SendDraft)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@mail_send], resolver: @scope_resolver)
      end

      input do
        field(:draft_id, :string, required?: true, example: "AAMkAGI2...")
      end

      output do
        field(:message, :map)
      end
    end

    action :reply_message do
      id("microsoft.outlook.message.reply")
      resource(:message)
      verb(:create)
      data_classification(:message_content)
      label("Reply to Outlook Mail message")
      description("Reply to an existing Outlook Mail message.")
      handler(Jido.Connect.MicrosoftOutlook.Handlers.Actions.ReplyMessage)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@mail_send], resolver: @scope_resolver)
      end

      input do
        field(:message_id, :string, required?: true, example: "AAMkAGI2...")
        field(:comment, :string, required?: true)
      end

      output do
        field(:sent, :boolean)
        field(:message_id, :string)
      end
    end

    action :reply_all_message do
      id("microsoft.outlook.message.reply_all")
      resource(:message)
      verb(:create)
      data_classification(:message_content)
      label("Reply-all to Outlook Mail message")
      description("Reply-all to an existing Outlook Mail message.")
      handler(Jido.Connect.MicrosoftOutlook.Handlers.Actions.ReplyAllMessage)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@mail_send], resolver: @scope_resolver)
      end

      input do
        field(:message_id, :string, required?: true, example: "AAMkAGI2...")
        field(:comment, :string, required?: true)
      end

      output do
        field(:sent, :boolean)
        field(:message_id, :string)
      end
    end

    action :move_message do
      id("microsoft.outlook.message.move")
      resource(:message)
      verb(:update)
      data_classification(:message_content)
      label("Move Outlook Mail message")
      description("Move an Outlook Mail message to a different folder.")
      handler(Jido.Connect.MicrosoftOutlook.Handlers.Actions.MoveMessage)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth(:user)
        scopes([@mail_read_write], resolver: @scope_resolver)
      end

      input do
        field(:message_id, :string, required?: true, example: "AAMkAGI2...")
        field(:destination_folder_id, :string, required?: true, example: "AAMkAGI2...")
      end

      output do
        field(:message, :map)
      end
    end
  end
end
