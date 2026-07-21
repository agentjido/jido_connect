defmodule Jido.Connect.Zendesk.Handlers.Actions.AddTicketCommentTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Zendesk.Handlers.Actions.AddTicketComment

  describe "run/2" do
    test "adds a public comment to a ticket" do
      input = %{ticket_id: 12345, body: "We are looking into this issue.", public: true}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, comment} = AddTicketComment.run(input, runtime)
      assert comment.id == 60_001
      assert comment.body == "We are looking into this issue."
      assert comment.public == true
      assert comment.ticket_id == 12345
    end

    test "adds a private comment (internal note) to a ticket" do
      input = %{ticket_id: 12345, body: "Internal note: escalated to engineering.", public: false}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, comment} = AddTicketComment.run(input, runtime)
      assert comment.body == "Internal note: escalated to engineering."
      assert comment.public == false
    end

    test "adds comment with explicit author_id" do
      input = %{ticket_id: 12345, body: "Update from agent.", author_id: 9002}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, comment} = AddTicketComment.run(input, runtime)
      assert comment.author_id == 9002
    end

    test "defaults to public comment when public not specified" do
      input = %{ticket_id: 12345, body: "A comment without public flag."}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:ok, comment} = AddTicketComment.run(input, runtime)
      assert comment.public == true
    end

    test "returns error for not-found ticket" do
      input = %{ticket_id: 99999, body: "Comment on missing ticket."}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "token"}
      }

      assert {:error, error} = AddTicketComment.run(input, runtime)
      assert error.status == 404
    end

    test "returns error on provider failure" do
      input = %{ticket_id: 12345, body: "Will fail."}

      runtime = %{
        credentials: %{zendesk_client: Jido.Connect.Zendesk.MockClient, api_key: "error_token"}
      }

      assert {:error, error} = AddTicketComment.run(input, runtime)
      assert error.status == 422
    end
  end
end
