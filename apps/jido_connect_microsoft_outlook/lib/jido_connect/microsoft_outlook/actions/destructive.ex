defmodule Jido.Connect.MicrosoftOutlook.Actions.Destructive do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @mail_read_write "Mail.ReadWrite"
  @scope_resolver Jido.Connect.MicrosoftOutlook.ScopeResolver

  actions do
    action :delete_message do
      id("microsoft.outlook.message.delete")
      resource(:message)
      verb(:delete)
      data_classification(:message_content)
      label("Delete Outlook Mail message")
      description("Permanently delete an Outlook Mail message.")
      handler(Jido.Connect.MicrosoftOutlook.Handlers.Actions.DeleteMessage)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@mail_read_write], resolver: @scope_resolver)
      end

      input do
        field(:message_id, :string, required?: true, example: "AAMkAGI2...")
      end

      output do
        field(:result, :map)
      end
    end

    action :delete_draft do
      id("microsoft.outlook.draft.delete")
      resource(:draft)
      verb(:delete)
      data_classification(:message_content)
      label("Delete Outlook Mail draft")
      description("Delete an Outlook Mail draft message.")
      handler(Jido.Connect.MicrosoftOutlook.Handlers.Actions.DeleteDraft)
      effect(:destructive, confirmation: :always)

      access do
        auth(:user)
        scopes([@mail_read_write], resolver: @scope_resolver)
      end

      input do
        field(:draft_id, :string, required?: true, example: "AAMkAGI2...")
      end

      output do
        field(:result, :map)
      end
    end
  end
end
