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

    configured_url =
      OAuth.authorize_url("https://provider.test/oauth/authorize?tenant=one",
        client_id: "client",
        state: "state",
        empty: "",
        missing: nil
      )

    assert configured_url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query() == %{
             "tenant" => "one",
             "client_id" => "client",
             "state" => "state"
           }

    assert OAuth.authorize_url("https://provider.test/oauth/authorize?tenant=one", empty: "") ==
             "https://provider.test/oauth/authorize?tenant=one"

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
    assert response.delivery == :rejected
    assert ProviderResponse.retryable?(response)
    assert ProviderResponse.retry_guidance(response) == :safe_to_retry

    non_idempotent_write_5xx =
      ProviderResponse.from_result!(:demo, {:ok, %{status: 503, body: %{}}},
        action_risk: :write,
        mutation?: true
      )

    refute ProviderResponse.retryable?(non_idempotent_write_5xx)
    assert ProviderResponse.retry_guidance(non_idempotent_write_5xx) == :do_not_retry

    idempotent_write_5xx =
      ProviderResponse.from_result!(:demo, {:ok, %{status: 503, body: %{}}},
        action_risk: :write,
        mutation?: true,
        provider_idempotency?: true
      )

    assert ProviderResponse.retryable?(idempotent_write_5xx)
    assert ProviderResponse.retry_guidance(idempotent_write_5xx) == :retry_with_idempotency

    assert ProviderResponse.to_public_map(response).body_summary == %{
             "type" => "map",
             "size" => 1,
             "keys" => ["api_key"]
           }

    refute inspect(response) =~ "secret"

    uncertain_write =
      ProviderResponse.from_result!(:demo, {:error, :timeout},
        action_risk: :external_write,
        mutation?: true
      )

    assert uncertain_write.delivery == :sent_outcome_unknown
    refute ProviderResponse.retryable?(uncertain_write)
    assert ProviderResponse.retry_guidance(uncertain_write) == :do_not_retry

    idempotent_write =
      ProviderResponse.from_result!(:demo, {:error, :timeout},
        action_risk: :write,
        mutation?: true,
        provider_idempotency?: true
      )

    assert ProviderResponse.retryable?(idempotent_write)
    assert ProviderResponse.retry_guidance(idempotent_write) == :retry_with_idempotency

    transport_timeout = %Req.TransportError{reason: :timeout}
    retryable_read = ProviderResponse.from_result!(:demo, {:error, transport_timeout})

    assert retryable_read.reason == :timeout
    assert ProviderResponse.retryable?(retryable_read)
    assert ProviderResponse.retry_guidance(retryable_read) == :safe_to_retry

    idempotent_transport_write =
      ProviderResponse.from_result!(:demo, {:error, transport_timeout},
        action_risk: :write,
        mutation?: true,
        provider_idempotency?: true
      )

    assert idempotent_transport_write.reason == :timeout
    assert ProviderResponse.retryable?(idempotent_transport_write)

    assert ProviderResponse.retry_guidance(idempotent_transport_write) ==
             :retry_with_idempotency

    not_sent =
      ProviderResponse.from_result!(:demo, {:error, :econnrefused},
        action_risk: :write,
        mutation?: true
      )

    assert not_sent.delivery == :not_sent
    assert ProviderResponse.retryable?(not_sent)
  end

  test "HTTP provider errors keep nested retry guidance in sync with action context" do
    for {mutation?, provider_idempotency?, expected} <- [
          {false, false, :safe_to_retry},
          {true, false, :do_not_retry},
          {true, true, :retry_with_idempotency}
        ] do
      action =
        Jido.Connect.RuntimeFixtures.spec(%{
          action: %{
            mutation?: mutation?,
            risk: if(mutation?, do: :write, else: :read),
            confirmation: if(mutation?, do: :always, else: :none),
            provider_idempotency?: provider_idempotency?
          }
        }).actions
        |> hd()

      assert {:error, provider_error} = Http.provider_error({:error, :timeout}, provider: :demo)
      error = Connect.Error.with_action_context(provider_error, action)
      public = Connect.Error.to_map(error)

      assert public.retry_guidance == expected
      assert error.details.response.retry_guidance == expected
      assert error.details.response.retryable? == public.retryable?
      assert error.details.response.action_risk == action.risk
      assert public.details["response"]["retry_guidance"] == Atom.to_string(expected)
    end
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

    assert {:ok, [1, 2]} = Webhook.decode_json("[1,2]", provider: :demo)

    for scalar <- ["42", ~s("text"), "true", "null"] do
      assert {:error, %Connect.Error.ProviderError{reason: :invalid_payload}} =
               Webhook.decode_json(scalar, provider: :demo)
    end

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

  test "transport reasons are stable, public, and safe to encode" do
    secret = "provider-secret-#{System.unique_integer([:positive])}"
    raw_reason = {:invalid_header_value, "authorization", secret}
    response = ProviderResponse.from_result!(:demo, {:error, raw_reason})

    assert response.reason == :invalid_header_value
    assert response.reason_details == %{source: :tuple, arity: 3}

    public = ProviderResponse.to_public_map(response)
    assert public.reason == :invalid_header_value
    assert public.reason_details == %{"source" => "tuple", "arity" => 3}
    assert is_binary(Jason.encode!(public))
    refute inspect(response) =~ secret

    assert {:error, error} = Http.provider_error({:error, raw_reason}, provider: :demo)
    refute inspect(error) =~ secret
    refute inspect(Connect.Error.to_map(error)) =~ secret

    assert {:error, status_error} =
             Http.provider_error({:ok, %{status: 400, body: %{}}},
               provider: :demo,
               reason: raw_reason
             )

    refute inspect(status_error) =~ secret
    refute inspect(Connect.Error.to_map(status_error)) =~ secret

    direct = ProviderResponse.new!(%{provider: :demo, reason: raw_reason})
    assert direct.reason == :invalid_header_value
    refute inspect(direct) =~ secret

    literal = %{response | reason: raw_reason, reason_details: %{raw: secret}}
    assert ProviderResponse.to_public_map(literal).reason == :invalid_header_value
    refute inspect(literal) =~ secret
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
