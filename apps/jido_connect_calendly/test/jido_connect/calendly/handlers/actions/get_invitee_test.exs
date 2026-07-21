defmodule Jido.Connect.Calendly.Handlers.Actions.GetInviteeTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly.Handlers.Actions.GetInvitee
  alias Jido.Connect.Calendly.Invitee

  describe "run/2" do
    test "returns invitee on success" do
      invitee =
        Invitee.new!(%{
          uri: "https://api.calendly.com/scheduled_events/ev1/invitees/inv1",
          email: "bob@example.com",
          name: "Bob Guest",
          status: "active",
          timezone: "America/New_York"
        })

      MockClient.stub(get_invitee: {:ok, invitee})
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:ok, %{invitee: result}} =
               GetInvitee.run(
                 %{
                   event_uri: "https://api.calendly.com/scheduled_events/ev1",
                   uri: "https://api.calendly.com/scheduled_events/ev1/invitees/inv1"
                 },
                 %{credentials: credentials}
               )

      assert result.email == "bob@example.com"
      assert result.name == "Bob Guest"
      assert result.status == "active"
      assert result.timezone == "America/New_York"
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :calendly, message: "Not found"}}

      MockClient.stub(get_invitee: error)
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               GetInvitee.run(
                 %{
                   event_uri: "https://api.calendly.com/scheduled_events/nonexistent",
                   uri: "https://api.calendly.com/scheduled_events/nonexistent/invitees/missing"
                 },
                 %{credentials: credentials}
               )
    end
  end
end
