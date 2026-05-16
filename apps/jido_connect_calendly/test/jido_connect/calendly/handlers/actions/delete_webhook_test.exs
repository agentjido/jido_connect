defmodule Jido.Connect.Calendly.Handlers.Actions.DeleteWebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Calendly.Handlers.Actions.DeleteWebhook

  describe "run/2" do
    test "returns deleted webhook result on success" do
      MockClient.stub(delete_webhook: {:ok, %{deleted: true, entity: "webhook_subscription"}})
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:ok, %{webhook: result}} =
               DeleteWebhook.run(
                 %{uri: "https://api.calendly.com/webhook_subscriptions/wh1"},
                 %{credentials: credentials}
               )

      assert result.deleted == true
      assert result.entity == "webhook_subscription"
    end

    test "returns error when client fails" do
      error =
        {:error, %Jido.Connect.Error.ProviderError{provider: :calendly, message: "Not found"}}

      MockClient.stub(delete_webhook: error)
      credentials = %{calendly_client: MockClient, api_key: "test-token"}

      assert {:error, %Jido.Connect.Error.ProviderError{}} =
               DeleteWebhook.run(
                 %{uri: "https://api.calendly.com/webhook_subscriptions/nonexistent"},
                 %{credentials: credentials}
               )
    end
  end
end
