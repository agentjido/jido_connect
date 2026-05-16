defmodule Jido.Connect.Calendly.Handlers.Actions.CreateWebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly.Handlers.Actions.CreateWebhook
  alias Jido.Connect.Calendly.WebhookSubscription

  describe "run/2" do
    test "returns webhook on success" do
      webhook =
        WebhookSubscription.new!(%{
          uri: "https://api.calendly.com/webhook_subscriptions/wh1",
          callback_url: "https://example.com/calendly/webhook",
          scope: "organization",
          organization_uri: "https://api.calendly.com/organizations/org1",
          events: ["invitee.created", "invitee.canceled"],
          state: "active"
        })

      MockClient.stub(create_webhook: {:ok, webhook})
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:ok, %{webhook: result}} =
               CreateWebhook.run(
                 %{
                   callback_url: "https://example.com/calendly/webhook",
                   events: ["invitee.created", "invitee.canceled"],
                   organization_uri: "https://api.calendly.com/organizations/org1",
                   scope: "organization"
                 },
                 %{credentials: credentials}
               )

      assert result.uri == "https://api.calendly.com/webhook_subscriptions/wh1"
      assert result.callback_url == "https://example.com/calendly/webhook"
      assert result.events == ["invitee.created", "invitee.canceled"]
      assert result.state == "active"
    end

    test "returns error when client fails" do
      error =
        {:error,
         %Jido.Connect.Error.ProviderError{provider: :calendly, message: "Invalid request"}}

      MockClient.stub(create_webhook: error)
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               CreateWebhook.run(
                 %{
                   callback_url: "https://example.com/calendly/webhook",
                   events: ["invitee.created"]
                 },
                 %{credentials: credentials}
               )
    end
  end
end
