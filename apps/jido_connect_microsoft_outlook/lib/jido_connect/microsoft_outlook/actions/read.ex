defmodule Jido.Connect.MicrosoftOutlook.Actions.Read do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @mail_read "Mail.Read"
  @mailbox_settings "MailboxSettings.Read"
  @scope_resolver Jido.Connect.MicrosoftOutlook.ScopeResolver

  actions do
    action :get_profile do
      id("microsoft.outlook.profile.get")
      resource(:profile)
      verb(:get)
      data_classification(:personal_data)
      label("Get Outlook Mail profile")
      description("Fetch Outlook Mail profile metadata for the authenticated user.")
      handler(Jido.Connect.MicrosoftOutlook.Handlers.Actions.GetProfile)
      effect(:read)

      access do
        auth(:user)
        scopes([@mailbox_settings], resolver: @scope_resolver)
      end

      input do
      end

      output do
        field(:profile, :map)
      end
    end

    action :list_messages do
      id("microsoft.outlook.messages.list")
      resource(:message)
      verb(:list)
      data_classification(:message_content)
      label("List Outlook Mail messages")
      description("List Outlook Mail message summaries from the authenticated user's mailbox.")
      handler(Jido.Connect.MicrosoftOutlook.Handlers.Actions.ListMessages)
      effect(:read)

      access do
        auth(:user)
        scopes([@mail_read], resolver: @scope_resolver)
      end

      input do
        field(:folder_id, :string, default: "inbox")
        field(:query, :string)
        field(:page_size, :integer, default: 25)
        field(:skip, :integer)
      end

      output do
        field(:messages, {:array, :map})
        field(:next_link, :string)
      end
    end

    action :get_message do
      id("microsoft.outlook.message.get")
      resource(:message)
      verb(:get)
      data_classification(:message_content)
      label("Get Outlook Mail message")
      description("Fetch a single Outlook Mail message by id.")
      handler(Jido.Connect.MicrosoftOutlook.Handlers.Actions.GetMessage)
      effect(:read)

      access do
        auth(:user)
        scopes([@mail_read], resolver: @scope_resolver)
      end

      input do
        field(:message_id, :string, required?: true, example: "AAMkAGI2...")
      end

      output do
        field(:message, :map)
      end
    end

    action :list_folders do
      id("microsoft.outlook.folders.list")
      resource(:folder)
      verb(:list)
      data_classification(:personal_data)
      label("List Outlook Mail folders")
      description("List Outlook Mail folders for the authenticated user's mailbox.")
      handler(Jido.Connect.MicrosoftOutlook.Handlers.Actions.ListFolders)
      effect(:read)

      access do
        auth(:user)
        scopes([@mail_read], resolver: @scope_resolver)
      end

      input do
        field(:page_size, :integer, default: 25)
      end

      output do
        field(:folders, {:array, :map})
        field(:next_link, :string)
      end
    end

    action :get_folder do
      id("microsoft.outlook.folder.get")
      resource(:folder)
      verb(:get)
      data_classification(:personal_data)
      label("Get Outlook Mail folder")
      description("Fetch a single Outlook Mail folder by id.")
      handler(Jido.Connect.MicrosoftOutlook.Handlers.Actions.GetFolder)
      effect(:read)

      access do
        auth(:user)
        scopes([@mail_read], resolver: @scope_resolver)
      end

      input do
        field(:folder_id, :string, required?: true, example: "AAMkAGI2...")
      end

      output do
        field(:folder, :map)
      end
    end
  end
end
