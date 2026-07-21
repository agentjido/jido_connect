defmodule Jido.Connect.Calendly.Handlers.Actions.GetEventTypeTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly.EventType
  alias Jido.Connect.Calendly.Handlers.Actions.GetEventType

  describe "run/2" do
    test "returns event type on success" do
      event_type =
        EventType.new!(%{
          uri: "https://api.calendly.com/event_types/i9j0k1l2",
          name: "30 Minute Meeting",
          duration: 30
        })

      MockClient.stub(get_event_type: {:ok, event_type})
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:ok, %{event_type: result}} =
               GetEventType.run(
                 %{uri: "https://api.calendly.com/event_types/i9j0k1l2"},
                 %{credentials: credentials}
               )

      assert result.uri == "https://api.calendly.com/event_types/i9j0k1l2"
      assert result.name == "30 Minute Meeting"
      assert result.duration == 30
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :calendly, message: "Not found"}}

      MockClient.stub(get_event_type: error)
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               GetEventType.run(
                 %{uri: "https://api.calendly.com/event_types/nonexistent"},
                 %{credentials: credentials}
               )
    end
  end
end
