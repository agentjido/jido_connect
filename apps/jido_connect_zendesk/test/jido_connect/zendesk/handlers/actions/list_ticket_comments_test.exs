defmodule Jido.Connect.Zendesk.Handlers.Actions.ListTicketCommentsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Zendesk.Handlers.Actions.ListTicketComments

  describe "run/2" do
    test "lists comments for a ticket with mock client" do
      input = %{ticket_id: 12345}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListTicketComments.run(input, runtime)
      assert length(result.items) == 2
      assert hd(result.items).id == 50001
      assert hd(result.items).body =~ "checked the email configuration"
      assert hd(result.items).author_id == 9001
      assert hd(result.items).public == true
      assert result.count == 2
    end

    test "passes pagination params" do
      input = %{ticket_id: 12345, page: 2}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, result} = ListTicketComments.run(input, runtime)
      assert result.items == []
      assert result.next_page == nil
    end
  end
end
