defmodule Jido.Connect.Zendesk.Actions.Tickets do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @scope_resolver Jido.Connect.Zendesk.ScopeResolver

  actions do
    action :list_tickets do
      id("zendesk.ticket.list")
      resource(:ticket)
      verb(:list)
      data_classification(:workspace_content)
      label("List tickets")
      description("List Zendesk tickets with pagination and sorting.")
      handler(Jido.Connect.Zendesk.Handlers.Actions.ListTickets)
      effect(:read)

      access do
        auth([:api_token, :oauth2], default: :api_token)
        policies([:instance_access])
        scopes(["read", "tickets:read"], resolver: @scope_resolver)
      end

      input do
        field(:page, :integer, default: nil, description: "Page number for offset pagination.")
        field(:per_page, :integer, default: nil, description: "Results per page (max 100).")
        field(:sort_by, :string, default: nil, description: "Field to sort by.")
        field(:sort_order, :string, default: nil, description: "Sort direction: asc or desc.")
      end

      output do
        field(:items, {:array, :map})
        field(:next_page, :string)
        field(:previous_page, :string)
        field(:count, :integer)
      end
    end

    action :search_tickets do
      id("zendesk.ticket.search")
      resource(:ticket)
      verb(:search)
      data_classification(:workspace_content)
      label("Search tickets")
      description("Search Zendesk tickets using a query string.")
      handler(Jido.Connect.Zendesk.Handlers.Actions.SearchTickets)
      effect(:read)

      access do
        auth([:api_token, :oauth2], default: :api_token)
        policies([:instance_access])
        scopes(["read", "tickets:read"], resolver: @scope_resolver)
      end

      input do
        field(:query, :string,
          required?: true,
          description: "Zendesk search query string.",
          example: "status:open priority:high"
        )

        field(:page, :integer, default: nil, description: "Page number for offset pagination.")
        field(:per_page, :integer, default: nil, description: "Results per page (max 100).")
        field(:sort_by, :string, default: nil, description: "Field to sort by.")
        field(:sort_order, :string, default: nil, description: "Sort direction: asc or desc.")
      end

      output do
        field(:items, {:array, :map})
        field(:next_page, :string)
        field(:previous_page, :string)
        field(:count, :integer)
      end
    end

    action :get_ticket do
      id("zendesk.ticket.get")
      resource(:ticket)
      verb(:get)
      data_classification(:workspace_content)
      label("Get ticket")
      description("Fetch a single Zendesk ticket by ID.")
      handler(Jido.Connect.Zendesk.Handlers.Actions.GetTicket)
      effect(:read)

      access do
        auth([:api_token, :oauth2], default: :api_token)
        policies([:instance_access])
        scopes(["read", "tickets:read"], resolver: @scope_resolver)
      end

      input do
        field(:ticket_id, :integer, required?: true, description: "Zendesk ticket ID.")
      end

      output do
        field(:id, :integer)
        field(:subject, :string)
        field(:status, :string)
        field(:priority, :string)
        field(:type, :string)
        field(:requester_id, :integer)
        field(:assignee_id, :integer)
        field(:group_id, :integer)
        field(:organization_id, :integer)
        field(:tags, {:array, :string})
        field(:created_at, :string)
        field(:updated_at, :string)
      end
    end

    action :list_ticket_comments do
      id("zendesk.ticket.comment.list")
      resource(:comment)
      verb(:list)
      data_classification(:workspace_content)
      label("List ticket comments")
      description("List comments for a Zendesk ticket.")
      handler(Jido.Connect.Zendesk.Handlers.Actions.ListTicketComments)
      effect(:read)

      access do
        auth([:api_token, :oauth2], default: :api_token)
        policies([:instance_access])
        scopes(["read", "tickets:read"], resolver: @scope_resolver)
      end

      input do
        field(:ticket_id, :integer, required?: true, description: "Zendesk ticket ID.")
        field(:page, :integer, default: nil, description: "Page number for offset pagination.")
        field(:per_page, :integer, default: nil, description: "Results per page.")
      end

      output do
        field(:items, {:array, :map})
        field(:next_page, :string)
        field(:previous_page, :string)
        field(:count, :integer)
      end
    end

    action :list_users do
      id("zendesk.user.list")
      resource(:user)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List users")
      description("List Zendesk users with optional role filter.")
      handler(Jido.Connect.Zendesk.Handlers.Actions.ListUsers)
      effect(:read)

      access do
        auth([:api_token, :oauth2], default: :api_token)
        policies([:instance_access])
        scopes(["read", "users:read"], resolver: @scope_resolver)
      end

      input do
        field(:page, :integer, default: nil, description: "Page number for offset pagination.")
        field(:per_page, :integer, default: nil, description: "Results per page.")

        field(:role, :string,
          default: nil,
          description: "Filter by role: end-user, agent, or admin."
        )
      end

      output do
        field(:items, {:array, :map})
        field(:next_page, :string)
        field(:previous_page, :string)
        field(:count, :integer)
      end
    end

    action :list_organizations do
      id("zendesk.organization.list")
      resource(:organization)
      verb(:list)
      data_classification(:workspace_metadata)
      label("List organizations")
      description("List Zendesk organizations with pagination.")
      handler(Jido.Connect.Zendesk.Handlers.Actions.ListOrganizations)
      effect(:read)

      access do
        auth([:api_token, :oauth2], default: :api_token)
        policies([:instance_access])
        scopes(["read"], resolver: @scope_resolver)
      end

      input do
        field(:page, :integer, default: nil, description: "Page number for offset pagination.")
        field(:per_page, :integer, default: nil, description: "Results per page.")
      end

      output do
        field(:items, {:array, :map})
        field(:next_page, :string)
        field(:previous_page, :string)
        field(:count, :integer)
      end
    end
  end
end
