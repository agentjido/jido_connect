defmodule Jido.Connect.Calendly.Handlers.Actions.ListInviteesTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly.Handlers.Actions.ListInvitees
  alias Jido.Connect.Calendly.Invitee
  alias Jido.Connect.Calendly.Pagination

  describe "run/2" do
    test "returns invitees list with pagination" do
      invitees = [
        Invitee.new!(%{
          uri: "https://api.calendly.com/scheduled_events/ev1/invitees/inv1",
          email: "bob@example.com",
          name: "Bob Guest"
        }),
        Invitee.new!(%{
          uri: "https://api.calendly.com/scheduled_events/ev1/invitees/inv2",
          email: "carol@example.com",
          name: "Carol Guest"
        })
      ]

      pagination =
        Pagination.new!(%{
          next_page: "https://api.calendly.com/scheduled_events/ev1/invitees?page=2",
          count: 2
        })

      MockClient.stub(list_invitees: {:ok, %{items: invitees, pagination: pagination}})
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:ok, result} =
               ListInvitees.run(
                 %{event_uri: "https://api.calendly.com/scheduled_events/ev1"},
                 %{credentials: credentials}
               )

      assert length(result.invitees) == 2
      assert hd(result.invitees).email == "bob@example.com"
      assert result.pagination.next_page =~ "page=2"
    end

    test "returns invitees list without pagination" do
      invitees = [
        Invitee.new!(%{
          uri: "https://api.calendly.com/scheduled_events/ev1/invitees/inv1",
          email: "bob@example.com"
        })
      ]

      MockClient.stub(list_invitees: {:ok, %{items: invitees}})
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:ok, result} =
               ListInvitees.run(
                 %{event_uri: "https://api.calendly.com/scheduled_events/ev1"},
                 %{credentials: credentials}
               )

      assert length(result.invitees) == 1
      refute Map.has_key?(result, :pagination)
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :calendly, message: "Not found"}}

      MockClient.stub(list_invitees: error)
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               ListInvitees.run(
                 %{event_uri: "https://api.calendly.com/scheduled_events/nonexistent"},
                 %{credentials: credentials}
               )
    end
  end
end
