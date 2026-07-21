defmodule Jido.Connect.Intercom.Actions.Writes do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Intercom.ScopeResolver

  actions do
    # ---------------------------------------------------------------------------
    # Contact write actions
    # ---------------------------------------------------------------------------

    action :create_contact do
      id("intercom.contact.create")
      resource(:contact)
      verb(:create)
      data_classification(:personal_data)
      label("Create contact")
      description("Create a new Intercom contact.")
      handler(Jido.Connect.Intercom.Handlers.Actions.CreateContact)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        policies([:workspace_access])
        scopes(["contacts:write"], resolver: @scope_resolver)
      end

      input do
        field(:email, :string, description: "Contact email address.")

        field(:name, :string, description: "Contact name.")

        field(:phone, :string, description: "Contact phone number.")

        field(:role, :string,
          default: "user",
          description: "Contact role (user, lead)."
        )

        field(:external_id, :string, description: "External ID for the contact.")

        field(:custom_attributes, :map,
          default: %{},
          description: "Custom attributes to set on the contact."
        )
      end

      output do
        field(:id, :string)
        field(:name, :string)
        field(:email, :string)
        field(:role, :string)
        field(:created_at, :integer)
        field(:updated_at, :integer)
      end
    end

    action :update_contact do
      id("intercom.contact.update")
      resource(:contact)
      verb(:update)
      data_classification(:personal_data)
      label("Update contact")
      description("Update an existing Intercom contact by ID.")
      handler(Jido.Connect.Intercom.Handlers.Actions.UpdateContact)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        policies([:workspace_access])
        scopes(["contacts:write"], resolver: @scope_resolver)
      end

      input do
        field(:contact_id, :string,
          required?: true,
          description: "Intercom contact ID."
        )

        field(:name, :string, description: "Updated contact name.")

        field(:email, :string, description: "Updated email address.")

        field(:phone, :string, description: "Updated phone number.")

        field(:role, :string, description: "Updated role.")

        field(:custom_attributes, :map,
          default: %{},
          description: "Custom attributes to update."
        )
      end

      output do
        field(:id, :string)
        field(:name, :string)
        field(:email, :string)
        field(:role, :string)
        field(:updated_at, :integer)
      end
    end

    # ---------------------------------------------------------------------------
    # Conversation write actions
    # ---------------------------------------------------------------------------

    action :reply_conversation do
      id("intercom.conversation.reply")
      resource(:conversation)
      verb(:update)
      data_classification(:message_content)
      label("Reply to conversation")
      description("Reply to an Intercom conversation as an admin or user.")
      handler(Jido.Connect.Intercom.Handlers.Actions.ReplyConversation)
      effect(:external_write, confirmation: :required_for_ai)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        policies([:workspace_access])
        scopes(["conversations:write"], resolver: @scope_resolver)
      end

      input do
        field(:conversation_id, :string,
          required?: true,
          description: "Intercom conversation ID."
        )

        field(:body, :string,
          required?: true,
          description: "Reply message body (HTML)."
        )

        field(:admin_id, :string,
          description: "Admin ID sending the reply. Required for admin replies."
        )

        field(:message_type, :string,
          default: "comment",
          description: "Message type: comment or note."
        )
      end

      output do
        field(:id, :string)
        field(:part_type, :string)
        field(:body, :string)
        field(:created_at, :integer)
      end
    end

    action :add_note do
      id("intercom.conversation.add_note")
      resource(:conversation)
      verb(:update)
      data_classification(:message_content)
      label("Add note to conversation")
      description("Add an internal note to an Intercom conversation.")
      handler(Jido.Connect.Intercom.Handlers.Actions.AddNote)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        policies([:workspace_access])
        scopes(["conversations:write"], resolver: @scope_resolver)
      end

      input do
        field(:conversation_id, :string,
          required?: true,
          description: "Intercom conversation ID."
        )

        field(:body, :string,
          required?: true,
          description: "Note body (HTML)."
        )

        field(:admin_id, :string,
          required?: true,
          description: "Admin ID creating the note."
        )
      end

      output do
        field(:id, :string)
        field(:part_type, :string)
        field(:body, :string)
        field(:created_at, :integer)
      end
    end

    action :assign_conversation do
      id("intercom.conversation.assign")
      resource(:conversation)
      verb(:update)
      data_classification(:workspace_metadata)
      label("Assign conversation")
      description("Assign an Intercom conversation to an admin or team.")
      handler(Jido.Connect.Intercom.Handlers.Actions.AssignConversation)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        policies([:workspace_access])
        scopes(["conversations:write"], resolver: @scope_resolver)
      end

      input do
        field(:conversation_id, :string,
          required?: true,
          description: "Intercom conversation ID."
        )

        field(:admin_id, :string, description: "Admin ID to assign to.")

        field(:team_id, :string, description: "Team ID to assign to.")

        field(:body, :string, description: "Optional assignment message body.")
      end

      output do
        field(:id, :string)
        field(:part_type, :string)
        field(:assigned_to, :map)
        field(:created_at, :integer)
      end
    end

    # ---------------------------------------------------------------------------
    # Tag write actions
    # ---------------------------------------------------------------------------

    action :tag_contact do
      id("intercom.contact.tag")
      resource(:contact)
      verb(:update)
      data_classification(:workspace_metadata)
      label("Tag contact")
      description("Apply a tag to one or more Intercom contacts.")
      handler(Jido.Connect.Intercom.Handlers.Actions.TagContact)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        policies([:workspace_access])
        scopes(["tags:write", "contacts:write"], resolver: @scope_resolver)
      end

      input do
        field(:name, :string,
          required?: true,
          description: "Tag name to apply."
        )

        field(:contact_ids, {:array, :string},
          required?: true,
          description: "List of Intercom contact IDs to tag."
        )
      end

      output do
        field(:id, :string)
        field(:name, :string)
        field(:type, :string)
        field(:applied_to, :map)
      end
    end

    action :untag_contact do
      id("intercom.contact.untag")
      resource(:contact)
      verb(:update)
      data_classification(:workspace_metadata)
      label("Untag contact")
      description("Remove a tag from one or more Intercom contacts.")
      handler(Jido.Connect.Intercom.Handlers.Actions.UntagContact)
      effect(:write, confirmation: :required_for_ai)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        policies([:workspace_access])
        scopes(["tags:write", "contacts:write"], resolver: @scope_resolver)
      end

      input do
        field(:tag_id, :string,
          required?: true,
          description: "Intercom tag ID to remove."
        )

        field(:contact_ids, {:array, :string},
          required?: true,
          description: "List of Intercom contact IDs to untag."
        )
      end

      output do
        field(:id, :string)
        field(:name, :string)
        field(:type, :string)
        field(:applied_to, :map)
      end
    end
  end
end
