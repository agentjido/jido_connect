defmodule Jido.Connect.Calendly.Handlers.Actions.CancelInviteeTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly.Handlers.Actions.CancelInvitee
  alias Jido.Connect.Calendly.Invitee

  describe "run/2" do
    test "returns canceled invitee on success" do
      invitee =
        Invitee.new!(%{
          uri: "https://api.calendly.com/scheduled_events/ev1/invitees/inv1",
          email: "bob@example.com",
          name: "Bob Guest",
          status: "canceled",
          canceled_by: "alice@example.com",
          cancellation_reason: "Schedule conflict"
        })

      MockClient.stub(cancel_invitee: {:ok, invitee})
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:ok, %{invitee: result}} =
               CancelInvitee.run(
                 %{
                   event_uri: "https://api.calendly.com/scheduled_events/ev1",
                   uri: "https://api.calendly.com/scheduled_events/ev1/invitees/inv1",
                   reason: "Schedule conflict"
                 },
                 %{credentials: credentials}
               )

      assert result.email == "bob@example.com"
      assert result.status == "canceled"
      assert result.canceled_by == "alice@example.com"
      assert result.cancellation_reason == "Schedule conflict"
    end

    test "returns canceled invitee without reason" do
      invitee =
        Invitee.new!(%{
          uri: "https://api.calendly.com/scheduled_events/ev1/invitees/inv1",
          email: "bob@example.com",
          status: "canceled"
        })

      MockClient.stub(cancel_invitee: {:ok, invitee})
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:ok, %{invitee: result}} =
               CancelInvitee.run(
                 %{
                   event_uri: "https://api.calendly.com/scheduled_events/ev1",
                   uri: "https://api.calendly.com/scheduled_events/ev1/invitees/inv1"
                 },
                 %{credentials: credentials}
               )

      assert result.status == "canceled"
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :calendly, message: "Not found"}}

      MockClient.stub(cancel_invitee: error)
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               CancelInvitee.run(
                 %{
                   event_uri: "https://api.calendly.com/scheduled_events/ev1",
                   uri: "https://api.calendly.com/scheduled_events/ev1/invitees/inv1"
                 },
                 %{credentials: credentials}
               )
    end
  end
end
