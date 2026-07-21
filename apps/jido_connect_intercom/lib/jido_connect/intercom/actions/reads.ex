defmodule Jido.Connect.Intercom.Actions.Reads do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Intercom.ScopeResolver

  actions do
    # ---------------------------------------------------------------------------
    # Contacts
    # ---------------------------------------------------------------------------

    action :list_contacts do
      id("intercom.contact.list")
      resource(:contact)
      verb(:list)
      data_classification(:workspace_content)
      label("List contacts")
      description("List Intercom contacts with pagination and query filters.")
      handler(Jido.Connect.Intercom.Handlers.Actions.ListContacts)
      effect(:read)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        policies([:workspace_access])
        scopes(["contacts:read"], resolver: @scope_resolver)
      end

      input do
        field(:per_page, :integer,
          default: nil,
          description: "Results per page (max 50)."
        )

        field(:order, :string,
          default: nil,
          description: "Sort direction: asc or desc."
        )

        field(:sort, :string,
          default: nil,
          description: "Field to sort by."
        )

        field(:created_after, :integer,
          default: nil,
          description: "Unix timestamp for filtering contacts created after."
        )

        field(:created_before, :integer,
          default: nil,
          description: "Unix timestamp for filtering contacts created before."
        )
      end

      output do
        field(:items, {:array, :map})
        field(:pagination, :map)
      end
    end

    action :search_contacts do
      id("intercom.contact.search")
      resource(:contact)
      verb(:search)
      data_classification(:workspace_content)
      label("Search contacts")
      description("Search Intercom contacts using a query string.")
      handler(Jido.Connect.Intercom.Handlers.Actions.SearchContacts)
      effect(:read)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        policies([:workspace_access])
        scopes(["contacts:read"], resolver: @scope_resolver)
      end

      input do
        field(:query, :string,
          required?: true,
          description: "Intercom search query (e.g. \"email:alice@example.com\")."
        )

        field(:per_page, :integer,
          default: nil,
          description: "Results per page."
        )

        field(:starting_after, :string,
          default: nil,
          description: "Cursor for pagination."
        )
      end

      output do
        field(:items, {:array, :map})
        field(:pagination, :map)
        field(:total_count, :integer)
      end
    end

    action :get_contact do
      id("intercom.contact.get")
      resource(:contact)
      verb(:get)
      data_classification(:workspace_content)
      label("Get contact")
      description("Fetch a single Intercom contact by ID.")
      handler(Jido.Connect.Intercom.Handlers.Actions.GetContact)
      effect(:read)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        policies([:workspace_access])
        scopes(["contacts:read"], resolver: @scope_resolver)
      end

      input do
        field(:contact_id, :string, required?: true, description: "Intercom contact ID.")
      end

      output do
        field(:id, :string)
        field(:name, :string)
        field(:email, :string)
        field(:phone, :string)
        field(:role, :string)
        field(:created_at, :integer)
        field(:updated_at, :integer)
      end
    end

    # ---------------------------------------------------------------------------
    # Conversations
    # ---------------------------------------------------------------------------

    action :list_conversations do
      id("intercom.conversation.list")
      resource(:conversation)
      verb(:list)
      data_classification(:workspace_content)
      label("List conversations")
      description("List Intercom conversations with pagination and filters.")
      handler(Jido.Connect.Intercom.Handlers.Actions.ListConversations)
      effect(:read)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        policies([:workspace_access])
        scopes(["conversations:read"], resolver: @scope_resolver)
      end

      input do
        field(:per_page, :integer,
          default: nil,
          description: "Results per page (max 50)."
        )

        field(:order, :string,
          default: nil,
          description: "Sort direction: asc or desc."
        )

        field(:sort, :string,
          default: nil,
          description: "Field to sort by."
        )

        field(:open, :boolean,
          default: nil,
          description: "Filter by open state."
        )

        field(:assignee_id, :string,
          default: nil,
          description: "Filter by admin assignee ID."
        )

        field(:team_ids, :string,
          default: nil,
          description: "Comma-separated team IDs to filter by."
        )
      end

      output do
        field(:items, {:array, :map})
        field(:pagination, :map)
      end
    end

    action :search_conversations do
      id("intercom.conversation.search")
      resource(:conversation)
      verb(:search)
      data_classification(:workspace_content)
      label("Search conversations")
      description("Search Intercom conversations using a query string.")
      handler(Jido.Connect.Intercom.Handlers.Actions.SearchConversations)
      effect(:read)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        policies([:workspace_access])
        scopes(["conversations:read"], resolver: @scope_resolver)
      end

      input do
        field(:query, :string,
          required?: true,
          description: "Intercom search query (e.g. \"open:true priority:urgent\")."
        )

        field(:per_page, :integer,
          default: nil,
          description: "Results per page."
        )

        field(:starting_after, :string,
          default: nil,
          description: "Cursor for pagination."
        )
      end

      output do
        field(:items, {:array, :map})
        field(:pagination, :map)
        field(:total_count, :integer)
      end
    end

    action :get_conversation do
      id("intercom.conversation.get")
      resource(:conversation)
      verb(:get)
      data_classification(:workspace_content)
      label("Get conversation")
      description("Fetch a single Intercom conversation by ID.")
      handler(Jido.Connect.Intercom.Handlers.Actions.GetConversation)
      effect(:read)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        policies([:workspace_access])
        scopes(["conversations:read"], resolver: @scope_resolver)
      end

      input do
        field(:conversation_id, :string,
          required?: true,
          description: "Intercom conversation ID."
        )
      end

      output do
        field(:id, :string)
        field(:state, :string)
        field(:open, :boolean)
        field(:title, :string)
        field(:priority, :string)
        field(:created_at, :integer)
        field(:updated_at, :integer)
      end
    end

    # ---------------------------------------------------------------------------
    # Admins
    # ---------------------------------------------------------------------------

    action :list_admins do
      id("intercom.admin.list")
      resource(:admin)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List admins")
      description("List Intercom admins (teammates) with pagination.")
      handler(Jido.Connect.Intercom.Handlers.Actions.ListAdmins)
      effect(:read)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        policies([:workspace_access])
        scopes(["admins:read"], resolver: @scope_resolver)
      end

      input do
        field(:per_page, :integer,
          default: nil,
          description: "Results per page."
        )
      end

      output do
        field(:items, {:array, :map})
        field(:pagination, :map)
      end
    end

    # ---------------------------------------------------------------------------
    # Teams
    # ---------------------------------------------------------------------------

    action :list_teams do
      id("intercom.team.list")
      resource(:team)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List teams")
      description("List Intercom teams with pagination.")
      handler(Jido.Connect.Intercom.Handlers.Actions.ListTeams)
      effect(:read)

      access do
        auth([:access_token, :oauth2], default: :access_token)
        policies([:workspace_access])
        scopes(["admins:read"], resolver: @scope_resolver)
      end

      input do
        field(:per_page, :integer,
          default: nil,
          description: "Results per page."
        )
      end

      output do
        field(:items, {:array, :map})
        field(:pagination, :map)
      end
    end
  end
end
