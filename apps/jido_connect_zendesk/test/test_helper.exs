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
end

# Ensure Req.Test.Ownership is running so that client tests using
# `setup {Req.Test, :verify_on_exit!}` work even when the umbrella
# cannot start the full application supervision tree.
unless Process.whereis(Req.Test.Ownership) do
  {:ok, _} = Req.Test.Ownership.start_link(name: Req.Test.Ownership)
end
