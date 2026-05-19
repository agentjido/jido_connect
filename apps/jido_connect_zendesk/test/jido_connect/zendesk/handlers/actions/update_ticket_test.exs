defmodule Jido.Connect.Zendesk.Handlers.Actions.UpdateTicketTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Zendesk.Handlers.Actions.UpdateTicket

  describe "run/2" do
    test "updates ticket status" do
      input = %{ticket_id: 12345, status: "solved"}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, ticket} = UpdateTicket.run(input, runtime)
      assert ticket.id == 12345
      assert ticket.status == "solved"
    end

    test "updates ticket assignee and group" do
      input = %{ticket_id: 12345, assignee_id: 9002, group_id: 102}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, ticket} = UpdateTicket.run(input, runtime)
      assert ticket.assignee_id == 9002
      assert ticket.group_id == 102
    end

    test "replaces tags on ticket" do
      input = %{ticket_id: 12345, tags: ["resolved", "escalated"]}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, ticket} = UpdateTicket.run(input, runtime)
      assert ticket.tags == ["resolved", "escalated"]
    end

    test "appends additional tags to ticket" do
      input = %{ticket_id: 12345, additional_tags: ["vip"]}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, ticket} = UpdateTicket.run(input, runtime)
      assert "vip" in ticket.tags
      assert "test" in ticket.tags
    end

    test "removes tags from ticket" do
      input = %{ticket_id: 12345, remove_tags: ["test"]}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, ticket} = UpdateTicket.run(input, runtime)
      assert "test" not in ticket.tags
    end

    test "updates priority and type together" do
      input = %{ticket_id: 12345, priority: "urgent", type: "problem"}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, ticket} = UpdateTicket.run(input, runtime)
      assert ticket.priority == "urgent"
      assert ticket.type == "problem"
    end

    test "returns error for not-found ticket" do
      input = %{ticket_id: 99999, status: "solved"}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:error, error} = UpdateTicket.run(input, runtime)
      assert error.status == 404
    end

    test "returns error on provider failure" do
      input = %{ticket_id: 12345, status: "solved"}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "error_token"}
      }

      assert {:error, error} = UpdateTicket.run(input, runtime)
      assert error.status == 422
    end
  end
end
