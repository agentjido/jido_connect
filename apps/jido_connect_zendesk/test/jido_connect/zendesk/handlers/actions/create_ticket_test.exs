defmodule Jido.Connect.Zendesk.Handlers.Actions.CreateTicketTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Zendesk.Handlers.Actions.CreateTicket

  describe "run/2" do
    test "creates a ticket with subject and description" do
      input = %{subject: "Login issue", description: "User cannot log in to the portal."}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, ticket} = CreateTicket.run(input, runtime)
      assert ticket.id == 99_001
      assert ticket.subject == "Login issue"
      assert ticket.description == "User cannot log in to the portal."
      assert ticket.status == "new"
      assert ticket.priority == "normal"
    end

    test "creates a ticket with all optional fields" do
      input = %{
        subject: "Critical outage",
        description: "Service is completely down.",
        requester_id: 9901,
        assignee_id: 9001,
        group_id: 101,
        type: "incident",
        priority: "urgent",
        tags: ["outage", "critical"],
        custom_fields: [%{id: 123, value: "premium"}]
      }

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, ticket} = CreateTicket.run(input, runtime)
      assert ticket.subject == "Critical outage"
      assert ticket.type == "incident"
      assert ticket.priority == "urgent"
      assert ticket.requester_id == 9901
      assert ticket.assignee_id == 9001
      assert ticket.group_id == 101
      assert ticket.tags == ["outage", "critical"]
      assert length(ticket.custom_fields) == 1
    end

    test "returns error on provider failure" do
      input = %{subject: "Bad ticket", description: "Will fail."}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "error_token"}
      }

      assert {:error, error} = CreateTicket.run(input, runtime)
      assert error.status == 422
    end
  end
end
