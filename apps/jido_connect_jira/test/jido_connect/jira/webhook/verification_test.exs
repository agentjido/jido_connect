defmodule Jido.Connect.Jira.Webhook.VerificationTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Jira.{CapturedDelivery, Webhook}
  alias Jido.Connect.Jira.Webhook.Verification
  alias Jido.Connect.WebhookDelivery

  # Test values from "Testing the webhook payload validation" in
  # https://developer.atlassian.com/cloud/jira/platform/webhooks/
  @doc_secret "It's a Secret to Everybody"
  @doc_payload "Hello World!"
  @doc_signature "sha256=a4771c39fbe90f317c7824e83ddef3caae9cb3d976c214ace1f2937e133263c9"

  # Raw bytes as Jira sends them: UTF-8 outside ASCII and a trailing newline.
  @raw_body ~s({"webhookEvent":"comment_created","comment":{"body":"Grüße, Zoë"}}\n)
  @secret "jira-webhook-test-secret"

  describe "verify_signature/3" do
    test "accepts the example from Atlassian's webhook documentation" do
      assert :ok = Verification.verify_signature(@doc_payload, @doc_signature, @doc_secret)
    end

    test "accepts a signature computed over the exact raw bytes" do
      assert :ok = Verification.verify_signature(@raw_body, sign(@raw_body, @secret), @secret)
    end

    test "rejects a changed body" do
      signature = sign(@raw_body, @secret)

      assert_auth_error(
        Verification.verify_signature(String.trim_trailing(@raw_body), signature, @secret),
        :invalid_signature
      )
    end

    test "rejects a wrong secret" do
      assert_auth_error(
        Verification.verify_signature(@raw_body, sign(@raw_body, "other-secret"), @secret),
        :invalid_signature
      )
    end

    test "rejects an empty or missing secret" do
      signature = sign(@raw_body, @secret)

      assert_auth_error(Verification.verify_signature(@raw_body, signature, ""), :missing_secret)
      assert_auth_error(Verification.verify_signature(@raw_body, signature, nil), :missing_secret)
    end

    test "rejects a missing signature" do
      assert_auth_error(
        Verification.verify_signature(@raw_body, nil, @secret),
        :missing_signature
      )

      assert_auth_error(Verification.verify_signature(@raw_body, "", @secret), :missing_signature)
    end

    test "rejects bare hex without the sha256= prefix" do
      "sha256=" <> hex = sign(@raw_body, @secret)

      assert_auth_error(
        Verification.verify_signature(@raw_body, hex, @secret),
        :invalid_signature
      )
    end

    test "rejects a base64 digest" do
      base64 = :hmac |> :crypto.mac(:sha256, @secret, @raw_body) |> Base.encode64()

      assert_auth_error(
        Verification.verify_signature(@raw_body, base64, @secret),
        :invalid_signature
      )

      assert_auth_error(
        Verification.verify_signature(@raw_body, "sha256=" <> base64, @secret),
        :invalid_signature
      )
    end

    test "rejects a signature or body that is not a string" do
      signature = sign(@raw_body, @secret)

      assert_auth_error(
        Verification.verify_signature(@raw_body, [signature], @secret),
        :invalid_signature
      )

      assert_auth_error(
        Verification.verify_signature(nil, signature, @secret),
        :invalid_signature
      )
    end

    test "rejects a sha1= prefix" do
      "sha256=" <> hex = sign(@raw_body, @secret)

      assert_auth_error(
        Verification.verify_signature(@raw_body, "sha1=" <> hex, @secret),
        :invalid_signature
      )
    end
  end

  describe "Jido.Connect.Jira.Webhook.verify_delivery/4" do
    test "returns a verified delivery with the normalized signal" do
      body = comment_delivery_body()

      headers = %{
        "content-type" => "application/json; charset=utf-8",
        "x-atlassian-webhook-identifier" => "7340912",
        "x-atlassian-webhook-flow" => "Primary",
        "x-hub-signature" => sign(body, @secret)
      }

      assert {:ok, %WebhookDelivery{} = delivery} =
               Webhook.verify_delivery(body, headers, @secret, [])

      assert delivery.provider == :jira
      assert delivery.signature_state == :verified
      assert delivery.delivery_id == "7340912"
      assert delivery.event == "comment_created"
      assert delivery.duplicate? == false
      assert delivery.payload["comment"]["id"] == "42727"
      assert delivery.normalized_signal.comment_id == "42727"
      assert delivery.normalized_signal.issue_key == "JCL-59"
    end

    test "rejects a changed body before decoding it" do
      headers = %{"x-hub-signature" => sign(comment_delivery_body(), @secret)}

      assert_auth_error(
        Webhook.verify_delivery(comment_delivery_body() <> " ", headers, @secret, []),
        :invalid_signature
      )
    end

    test "marks an identifier seen before as a duplicate" do
      body = comment_delivery_body()

      headers = %{
        "X-Atlassian-Webhook-Identifier" => "7340912",
        "X-Hub-Signature" => sign(body, @secret)
      }

      assert {:ok, %WebhookDelivery{duplicate?: true}} =
               Webhook.verify_delivery(body, headers, @secret, seen_delivery_ids: ["7340912"])
    end

    test "rejects a signed body that is not a JSON object" do
      for body <- ["not json", "[]"] do
        headers = %{"x-hub-signature" => sign(body, @secret)}

        assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_payload}} =
                 Webhook.verify_delivery(body, headers, @secret, [])
      end
    end

    test "keeps a verified delivery without signal for an event the triggers do not normalize" do
      # Derived: the captured issue creation under an event name the triggers
      # do not normalize.
      body =
        CapturedDelivery.payload!("issue_created")
        |> Map.put("webhookEvent", "jira:issue_deleted")
        |> Jason.encode!()

      headers = %{"x-hub-signature" => sign(body, @secret)}

      assert {:ok, %WebhookDelivery{event: "jira:issue_deleted", normalized_signal: nil}} =
               Webhook.verify_delivery(body, headers, @secret, [])
    end
  end

  describe "webhook triggers" do
    test "declare a hex HMAC-SHA256 signature in x-hub-signature" do
      triggers = Jido.Connect.Jira.integration().triggers

      assert Enum.map(triggers, & &1.id) == ["jira.issue.changed", "jira.comment.changed"]

      for trigger <- triggers do
        assert %{kind: :jira_webhook, signature: :hmac_sha256, header: "x-hub-signature"} =
                 trigger.verification
      end
    end
  end

  # The raw body of a captured administrator delivery, signed again below
  # with this test's secret.
  defp comment_delivery_body, do: CapturedDelivery.capture!("comment_created")["body"]

  defp sign(body, secret) do
    "sha256=" <> (:hmac |> :crypto.mac(:sha256, secret, body) |> Base.encode16(case: :lower))
  end

  defp assert_auth_error(result, reason) do
    assert {:error, %Jido.Connect.Error.AuthError{reason: ^reason}} = result
  end
end
