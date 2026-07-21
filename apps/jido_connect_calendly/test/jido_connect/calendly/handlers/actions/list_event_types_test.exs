defmodule Jido.Connect.Calendly.Handlers.Actions.ListEventTypesTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly.EventType
  alias Jido.Connect.Calendly.Handlers.Actions.ListEventTypes
  alias Jido.Connect.Calendly.Pagination

  describe "run/2" do
    test "returns event types list with pagination" do
      event_types = [
        EventType.new!(%{uri: "https://api.calendly.com/event_types/et1", name: "Meeting 1"}),
        EventType.new!(%{uri: "https://api.calendly.com/event_types/et2", name: "Meeting 2"})
      ]

      pagination =
        Pagination.new!(%{next_page: "https://api.calendly.com/event_types?page=2", count: 2})

      MockClient.stub(list_event_types: {:ok, %{items: event_types, pagination: pagination}})
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:ok, result} = ListEventTypes.run(%{}, %{credentials: credentials})
      assert length(result.event_types) == 2
      assert hd(result.event_types).uri == "https://api.calendly.com/event_types/et1"
      assert result.pagination.next_page =~ "page=2"
    end

    test "returns event types list without pagination" do
      event_types = [EventType.new!(%{uri: "https://api.calendly.com/event_types/et1"})]
      MockClient.stub(list_event_types: {:ok, %{items: event_types}})
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:ok, result} = ListEventTypes.run(%{}, %{credentials: credentials})
      assert length(result.event_types) == 1
      refute Map.has_key?(result, :pagination)
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :calendly, message: "Unauthorized"}}

      MockClient.stub(list_event_types: error)
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               ListEventTypes.run(%{}, %{credentials: credentials})
    end

    test "passes user_uri and organization_uri to client" do
      MockClient.stub(list_event_types: {:ok, %{items: []}})

      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:ok, _} =
               ListEventTypes.run(
                 %{user_uri: "https://api.calendly.com/users/u1"},
                 %{credentials: credentials}
               )
    end
  end
end
