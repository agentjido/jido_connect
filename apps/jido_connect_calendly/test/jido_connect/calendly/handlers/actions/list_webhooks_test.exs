defmodule Jido.Connect.Calendly.Handlers.Actions.ListWebhooksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly.Handlers.Actions.ListWebhooks
  alias Jido.Connect.Calendly.Pagination
  alias Jido.Connect.Calendly.WebhookSubscription

  describe "run/2" do
    test "returns webhooks list with pagination" do
      webhooks = [
        WebhookSubscription.new!(%{
          uri: "https://api.calendly.com/webhook_subscriptions/wh1",
          callback_url: "https://example.com/webhook1",
          events: ["invitee.created"],
          state: "active"
        }),
        WebhookSubscription.new!(%{
          uri: "https://api.calendly.com/webhook_subscriptions/wh2",
          callback_url: "https://example.com/webhook2",
          events: ["invitee.canceled"],
          state: "active"
        })
      ]

      pagination =
        Pagination.new!(%{
          next_page: "https://api.calendly.com/webhook_subscriptions?page=2",
          count: 2
        })

      MockClient.stub(list_webhooks: {:ok, %{items: webhooks, pagination: pagination}})
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:ok, result} =
               ListWebhooks.run(
                 %{organization_uri: "https://api.calendly.com/organizations/org1"},
                 %{credentials: credentials}
               )

      assert length(result.webhooks) == 2
      assert hd(result.webhooks).callback_url == "https://example.com/webhook1"
      assert result.pagination.next_page =~ "page=2"
    end

    test "returns webhooks list without pagination" do
      webhooks = [
        WebhookSubscription.new!(%{
          uri: "https://api.calendly.com/webhook_subscriptions/wh1",
          callback_url: "https://example.com/webhook1",
          events: ["invitee.created"],
          state: "active"
        })
      ]

      MockClient.stub(list_webhooks: {:ok, %{items: webhooks}})
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:ok, result} = ListWebhooks.run(%{}, %{credentials: credentials})

      assert length(result.webhooks) == 1
      refute Map.has_key?(result, :pagination)
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :calendly, message: "Unauthorized"}}

      MockClient.stub(list_webhooks: error)
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               ListWebhooks.run(%{}, %{credentials: credentials})
    end
  end
end
