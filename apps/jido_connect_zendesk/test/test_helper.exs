ExUnit.start()

defmodule Jido.Connect.Zendesk.MockClient do
  @moduledoc false

  def list_tickets("token", opts) do
    page = Keyword.get(opts, :page)
    _per_page = Keyword.get(opts, :per_page)

    tickets =
      if page == 2 do
        []
      else
        [
          ticket_payload(12345, "Cannot reset password", "open", "normal", "incident"),
          ticket_payload(
            12346,
            "Billing inquiry for enterprise plan",
            "pending",
            "high",
            "question"
          )
        ]
      end

    count = if page == 2, do: 0, else: 2

    next_page =
      if page == 2,
        do: nil,
        else: "https://example.zendesk.com/api/v2/tickets.json?page=2"

    {:ok,
     %{
       items: tickets,
       next_page: next_page,
       previous_page:
         if(page == 2, do: "https://example.zendesk.com/api/v2/tickets.json?page=1", else: nil),
       count: count
     }}
  end

  def search_tickets("status:open priority:high", "token", opts) do
    _page = Keyword.get(opts, :page)

    {:ok,
     %{
       items: [ticket_payload(12345, "Cannot reset password", "open", "high", "incident")],
       next_page: nil,
       previous_page: nil,
       count: 1
     }}
  end

  def search_tickets(_query, "token", _opts) do
    {:ok,
     %{
       items: [],
       next_page: nil,
       previous_page: nil,
       count: 0
     }}
  end

  def get_ticket(12345, "token", _opts) do
    {:ok,
     Map.drop(ticket_payload(12345, "Cannot reset password", "open", "normal", "incident"), [
       :metadata
     ])}
  end

  def get_ticket(99999, "token", _opts) do
    {:error,
     %Jido.Connect.Error.ProviderError{
       message: "Zendesk API request failed",
       provider: :zendesk,
       reason: :http_error,
       status: 404,
       details: %{message: "Not found", body: %{"error" => "RecordNotFound"}}
     }}
  end

  def list_ticket_comments(12345, "token", opts) do
    page = Keyword.get(opts, :page)

    comments =
      if page == 2 do
        []
      else
        [
          %{
            id: 50_001,
            body: "I've checked the email configuration on our end.",
            html_body: "<p>I've checked the email configuration on our end.</p>",
            plain_body: "I've checked the email configuration on our end.",
            author_id: 9001,
            public: true,
            ticket_id: 12345,
            created_at: "2026-03-15T11:00:00Z"
          },
          %{
            id: 50_002,
            body: "Thanks, looking into it.",
            html_body: "<p>Thanks, looking into it.</p>",
            plain_body: "Thanks, looking into it.",
            author_id: 9901,
            public: true,
            ticket_id: 12345,
            created_at: "2026-03-15T12:00:00Z"
          }
        ]
      end

    {:ok,
     %{
       items: comments,
       next_page:
         if(page != 2,
           do: "https://example.zendesk.com/api/v2/tickets/12345/comments.json?page=2",
           else: nil
         ),
       previous_page: nil,
       count: 2
     }}
  end

  def list_users("token", opts) do
    page = Keyword.get(opts, :page)
    role = Keyword.get(opts, :role)

    all_users = [
      %{
        id: 9001,
        email: "alice@example.com",
        name: "Alice Nakamura",
        role: "agent",
        active: true,
        tags: ["support", "tier-1"]
      },
      %{
        id: 9901,
        email: "bob@example.com",
        name: "Bob Martinez",
        role: "end-user",
        active: true,
        tags: []
      }
    ]

    users =
      case role do
        "agent" -> Enum.filter(all_users, &(&1.role == "agent"))
        _ -> if page == 2, do: [], else: all_users
      end

    {:ok,
     %{
       items: users,
       next_page: nil,
       previous_page: nil,
       count: length(users)
     }}
  end

  def list_organizations("token", opts) do
    page = Keyword.get(opts, :page)

    orgs =
      if page == 2 do
        []
      else
        [
          %{
            id: 201,
            name: "Acme Corp",
            domain_names: ["acme.com"],
            tags: ["enterprise", "vip"]
          }
        ]
      end

    {:ok,
     %{
       items: orgs,
       next_page: nil,
       previous_page: nil,
       count: length(orgs)
     }}
  end

  defp ticket_payload(id, subject, status, priority, type) do
    %{
      id: id,
      subject: subject,
      description: "Test description for ticket #{id}",
      status: status,
      type: type,
      priority: priority,
      requester_id: 9901,
      assignee_id: 9001,
      group_id: 101,
      organization_id: 201,
      tags: ["test"],
      custom_fields: [],
      created_at: "2026-03-15T10:30:00Z",
      updated_at: "2026-05-10T14:22:00Z"
    }
  end

  # ---------------------------------------------------------------------------
  # Write operations (mock)
  # ---------------------------------------------------------------------------

  def create_ticket(attrs, "token", _opts) do
    id = 99_001

    ticket = %{
      id: id,
      subject: Map.get(attrs, :subject),
      description: Map.get(attrs, :description),
      status: Map.get(attrs, :status, "new"),
      type: Map.get(attrs, :type),
      priority: Map.get(attrs, :priority, "normal"),
      requester_id: Map.get(attrs, :requester_id, 9901),
      assignee_id: Map.get(attrs, :assignee_id),
      group_id: Map.get(attrs, :group_id),
      organization_id: 201,
      tags: Map.get(attrs, :tags, []),
      custom_fields: Map.get(attrs, :custom_fields, []),
      created_at: "2026-05-19T10:00:00Z",
      updated_at: "2026-05-19T10:00:00Z"
    }

    {:ok, ticket}
  end

  def create_ticket(_attrs, "error_token", _opts) do
    {:error,
     %Jido.Connect.Error.ProviderError{
       message: "Zendesk API request failed",
       provider: :zendesk,
       reason: :http_error,
       status: 422,
       details: %{message: "Invalid attribute", body: %{"error" => "InvalidAttribute"}}
     }}
  end

  def update_ticket(12345, attrs, "token", _opts) do
    base = ticket_payload(12345, "Cannot reset password", "open", "normal", "incident")

    updated =
      Map.merge(base, %{
        status: Map.get(attrs, :status, base.status),
        priority: Map.get(attrs, :priority, base.priority),
        type: Map.get(attrs, :type, base.type),
        assignee_id: Map.get(attrs, :assignee_id, base.assignee_id),
        group_id: Map.get(attrs, :group_id, base.group_id),
        updated_at: "2026-05-19T12:00:00Z"
      })

    updated =
      case Map.get(attrs, :tags) do
        nil -> updated
        tags -> Map.put(updated, :tags, tags)
      end

    updated =
      case Map.get(attrs, :additional_tags) do
        nil -> updated
        add -> Map.update!(updated, :tags, &(&1 ++ add))
      end

    updated =
      case Map.get(attrs, :remove_tags) do
        nil -> updated
        remove -> Map.update!(updated, :tags, &Enum.reject(&1, fn t -> t in remove end))
      end

    {:ok, updated}
  end

  def update_ticket(99999, _attrs, "token", _opts) do
    {:error,
     %Jido.Connect.Error.ProviderError{
       message: "Zendesk API request failed",
       provider: :zendesk,
       reason: :http_error,
       status: 404,
       details: %{message: "Not found", body: %{"error" => "RecordNotFound"}}
     }}
  end

  def update_ticket(_ticket_id, _attrs, "error_token", _opts) do
    {:error,
     %Jido.Connect.Error.ProviderError{
       message: "Zendesk API request failed",
       provider: :zendesk,
       reason: :http_error,
       status: 422,
       details: %{message: "Invalid attribute", body: %{"error" => "InvalidAttribute"}}
     }}
  end

  def add_ticket_comment(12345, comment_attrs, "token", _opts) do
    comment_id = 60_001

    comment = %{
      id: comment_id,
      body: Map.get(comment_attrs, :body, ""),
      public: Map.get(comment_attrs, :public, true),
      author_id: Map.get(comment_attrs, :author_id, 9001),
      ticket_id: 12345,
      created_at: "2026-05-19T12:30:00Z"
    }

    {:ok, comment}
  end

  def add_ticket_comment(99999, _comment_attrs, "token", _opts) do
    {:error,
     %Jido.Connect.Error.ProviderError{
       message: "Zendesk API request failed",
       provider: :zendesk,
       reason: :http_error,
       status: 404,
       details: %{message: "Not found", body: %{"error" => "RecordNotFound"}}
     }}
  end

  def add_ticket_comment(_ticket_id, _comment_attrs, "error_token", _opts) do
    {:error,
     %Jido.Connect.Error.ProviderError{
       message: "Zendesk API request failed",
       provider: :zendesk,
       reason: :http_error,
       status: 422,
       details: %{message: "Invalid attribute", body: %{"error" => "InvalidAttribute"}}
     }}
  end
end

# Ensure Req.Test.Ownership is running so that client tests using
# `setup {Req.Test, :verify_on_exit!}` work even when the umbrella
# cannot start the full application supervision tree.
unless Process.whereis(Req.Test.Ownership) do
  {:ok, _} = Req.Test.Ownership.start_link(name: Req.Test.Ownership)
end
