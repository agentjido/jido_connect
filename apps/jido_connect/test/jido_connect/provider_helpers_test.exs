defmodule Jido.Connect.ProviderHelpersTest do
  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.{Http, OAuth, Polling, ProviderResponse, Webhook, WebhookDelivery}

  test "OAuth helpers build URLs and require configured secrets" do
    url =
      OAuth.authorize_url("https://provider.test/oauth/authorize",
        client_id: "client",
        redirect_uri: "https://demo.test/callback",
        scope: "read write",
        empty: "",
        missing: nil
      )

    params = url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

    assert params == %{
             "client_id" => "client",
             "redirect_uri" => "https://demo.test/callback",
             "scope" => "read write"
           }

    System.put_env("JIDO_CONNECT_TEST_SECRET", "secret")

    on_exit(fn ->
      System.delete_env("JIDO_CONNECT_TEST_SECRET")
    end)

    assert OAuth.fetch_required!([], :client_secret, "JIDO_CONNECT_TEST_SECRET") == "secret"
    assert %Req.Request{} = OAuth.req(base_url: "https://provider.test/token")
  end

  test "HTTP helpers normalize provider response failures" do
    assert %Req.Request{} = Http.bearer_request("https://provider.test", "token")

    basic_request =
      Http.basic_request("https://provider.test", "user@example.com", "api-token")

    assert basic_request.headers["authorization"] == [
             "Basic " <> Base.encode64("user@example.com:api-token")
           ]

    assert Http.url_with_query("/v1/resources?fixed=yes", item: "one", item: "two") ==
             "/v1/resources?fixed=yes&item=one&item=two"

    assert {:ok, %{"ok" => true}} =
             Http.handle_map_response({:ok, %{status: 200, body: %{"ok" => true}}},
               provider: :demo
             )

    assert {:error,
            %Connect.Error.ProviderError{
              provider: :demo,
              reason: :http_error,
              status: 429,
              details: %{message: "rate limited", response: %{status: 429, retryable?: true}}
            }} =
             Http.provider_error({:ok, %{status: 429, body: %{"message" => "rate limited"}}},
               provider: :demo,
               message: "Demo API request failed"
             )

    assert {:error, %Connect.Error.ProviderError{provider: :demo, reason: :request_error}} =
             Http.provider_error({:error, :timeout}, provider: :demo)

    response =
      ProviderResponse.from_result!(
        :demo,
        {:ok, %{status: 503, headers: [{"retry-after", "30"}], body: %{"api_key" => "secret"}}}
      )

    assert response.retry_after == 30
    assert ProviderResponse.retryable?(response)

    assert ProviderResponse.to_public_map(response).body_summary == %{
             "type" => "map",
             "size" => 1,
             "keys" => ["api_key"]
           }

    refute inspect(response) =~ "secret"
  end

  test "webhook helpers verify HMACs and decode JSON" do
    body = ~s({"ok":true})
    signature = "sha256=" <> Connect.Security.hmac_sha256_hex("secret", body)

    assert :ok =
             Webhook.verify_hmac_sha256(body, signature, "secret",
               prefix: "sha256=",
               invalid_signature_reason: :bad_signature
             )

    assert {:error, %Connect.Error.AuthError{reason: :bad_signature}} =
             Webhook.verify_hmac_sha256(body, "sha256=bad", "secret",
               prefix: "sha256=",
               invalid_signature_reason: :bad_signature
             )

    assert {:error, %Connect.Error.AuthError{reason: :missing_secret}} =
             Webhook.verify_hmac_sha256(body, signature, nil)

    assert {:ok, %{"ok" => true}} = Webhook.decode_json(body, provider: :demo)

    assert {:error, %Connect.Error.ProviderError{reason: :invalid_payload}} =
             Webhook.decode_json("not-json", provider: :demo)

    assert Webhook.header(%{"x-demo-header" => "value"}, "X-Demo-Header") == "value"
    assert Webhook.header(%{"X-Demo-Header" => "value"}, "x-demo-header") == "value"
    assert Webhook.header(%{"x_demo_header" => "value"}, "x-demo-header") == "value"
    assert Webhook.duplicate?("delivery_1", ["delivery_1"])

    delivery =
      WebhookDelivery.verified!(:demo,
        delivery_id: "delivery_1",
        event: "demo.created",
        headers: %{"authorization" => "secret"},
        payload: %{"ok" => true},
        metadata: %{token: "secret"}
      )
      |> WebhookDelivery.mark_duplicate()
      |> WebhookDelivery.put_signal(%{id: "signal_1"})

    assert delivery.duplicate?
    assert WebhookDelivery.to_public_map(delivery).headers["authorization"] == "[redacted]"
    assert WebhookDelivery.to_public_map(delivery).metadata["token"] == "[redacted]"
    refute inspect(delivery) =~ "secret"
  end

  test "polling helpers manage checkpoint params" do
    assert Polling.put_checkpoint_param([state: "all"], :since, nil) == [state: "all"]

    assert Polling.put_checkpoint_param([state: "all"], :since, "cursor") == [
             since: "cursor",
             state: "all"
           ]

    assert Polling.latest_checkpoint(
             [%{updated_at: "2026-04-24T20:00:00Z"}, %{updated_at: "2026-04-24T21:00:00Z"}],
             :updated_at,
             nil
           ) == "2026-04-24T21:00:00Z"

    assert Polling.latest_checkpoint([], :updated_at, "fallback") == "fallback"
  end
end
