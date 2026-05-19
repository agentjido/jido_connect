defmodule Jido.Connect.Zendesk.Handlers.Actions.GetTicketTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Zendesk.Handlers.Actions.GetTicket

  describe "run/2" do
    test "fetches a ticket by id with mock client" do
      input = %{ticket_id: 12345}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, ticket} = GetTicket.run(input, runtime)
      assert ticket.id == 12345
      assert ticket.subject == "Cannot reset password"
      assert ticket.status == "open"
      assert ticket.priority == "normal"
      assert ticket.type == "incident"
    end

    test "returns error for not-found ticket" do
      input = %{ticket_id: 99999}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:error, error} = GetTicket.run(input, runtime)
      assert error.status == 404
    end
  end
end
