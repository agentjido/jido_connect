defmodule Jido.Connect.InboundWebhook.VerificationTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.InboundWebhook.Verification
  alias Jido.Connect.InboundWebhook.VerificationProfile

  describe "parse_headers/2" do
    test "extracts signature from default header" do
      profile = VerificationProfile.new!(%{})
      headers = %{"x-signature" => "abc123"}

      assert %{signature: "abc123", timestamp: nil} =
               Verification.parse_headers(headers, profile)
    end

    test "extracts signature and timestamp from custom headers" do
      profile =
        VerificationProfile.new!(%{
          signature_header: "x-hub-signature-256",
          timestamp_header: "x-timestamp"
        })

      headers = %{"x-hub-signature-256" => "sha256=abc", "x-timestamp" => "1700000000"}

      assert %{signature: "sha256=abc", timestamp: "1700000000"} =
               Verification.parse_headers(headers, profile)
    end

    test "returns nil when headers are missing" do
      profile = VerificationProfile.new!(%{})
      headers = %{}

      assert %{signature: nil, timestamp: nil} =
               Verification.parse_headers(headers, profile)
    end

    test "normalizes header keys case-insensitively" do
      profile = VerificationProfile.new!(%{})
      headers = %{"X-Signature" => "abc123"}

      assert %{signature: "abc123"} = Verification.parse_headers(headers, profile)
    end
  end

  describe "verify_signature/4" do
    test "verifies valid HMAC-SHA256 signature with no prefix" do
      profile = VerificationProfile.new!(%{})
      body = ~s({"event":"test"})
      secret = "my-secret"
      signature = compute_hmac(secret, body)

      assert :ok = Verification.verify_signature(body, signature, secret, profile)
    end

    test "verifies valid HMAC-SHA256 signature with prefix" do
      profile = VerificationProfile.new!(%{digest_prefix: "sha256="})
      body = ~s({"event":"test"})
      secret = "my-secret"
      hex = compute_hmac(secret, body)
      signature = "sha256=#{hex}"

      assert :ok = Verification.verify_signature(body, signature, secret, profile)
    end

    test "rejects invalid signature" do
      profile = VerificationProfile.new!(%{})
      body = ~s({"event":"test"})
      secret = "my-secret"

      assert {:error, %Jido.Connect.Error.AuthError{reason: :invalid_signature}} =
               Verification.verify_signature(body, "badsig", secret, profile)
    end

    test "rejects missing secret" do
      profile = VerificationProfile.new!(%{})

      assert {:error, %Jido.Connect.Error.AuthError{reason: :missing_signing_secret}} =
               Verification.verify_signature("body", "sig", nil, profile)
    end

    test "rejects empty secret" do
      profile = VerificationProfile.new!(%{})

      assert {:error, %Jido.Connect.Error.AuthError{reason: :missing_signing_secret}} =
               Verification.verify_signature("body", "sig", "", profile)
    end

    test "rejects missing signature" do
      profile = VerificationProfile.new!(%{})

      assert {:error, %Jido.Connect.Error.AuthError{reason: :missing_signature}} =
               Verification.verify_signature("body", nil, "secret", profile)
    end
  end

  describe "verify_request/5" do
    test "verifies valid request with no timestamp header" do
      profile = VerificationProfile.new!(%{})
      body = ~s({"event":"test"})
      secret = "my-secret"
      signature = compute_hmac(secret, body)
      headers = %{"x-signature" => signature}

      assert {:ok, %{"event" => "test"}} =
               Verification.verify_request(body, headers, secret, profile)
    end

    test "verifies valid request with fresh timestamp" do
      profile =
        VerificationProfile.new!(%{
          timestamp_header: "x-timestamp",
          timestamp_tolerance_seconds: 300
        })

      body = ~s({"event":"test"})
      secret = "my-secret"
      now = 1_700_000_000
      signature = compute_hmac(secret, body)

      headers = %{
        "x-signature" => signature,
        "x-timestamp" => "1700000000"
      }

      assert {:ok, %{"event" => "test"}} =
               Verification.verify_request(body, headers, secret, profile, now: now)
    end

    test "rejects request with stale timestamp" do
      profile =
        VerificationProfile.new!(%{
          timestamp_header: "x-timestamp",
          timestamp_tolerance_seconds: 300
        })

      body = ~s({"event":"test"})
      secret = "my-secret"
      now = 1_700_001_000
      signature = compute_hmac(secret, body)

      headers = %{
        "x-signature" => signature,
        "x-timestamp" => "1700000000"
      }

      assert {:error, %Jido.Connect.Error.AuthError{reason: :stale_timestamp}} =
               Verification.verify_request(body, headers, secret, profile, now: now)
    end

    test "rejects request with invalid JSON body" do
      profile = VerificationProfile.new!(%{})
      body = "not json"
      secret = "my-secret"
      signature = compute_hmac(secret, body)
      headers = %{"x-signature" => signature}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :webhook}} =
               Verification.verify_request(body, headers, secret, profile)
    end
  end

  describe "verify_delivery/5" do
    test "returns a WebhookDelivery struct on success" do
      profile = VerificationProfile.new!(%{})
      body = ~s({"event":"test"})
      secret = "my-secret"
      signature = compute_hmac(secret, body)
      headers = %{"x-signature" => signature}

      assert {:ok, %Jido.Connect.WebhookDelivery{} = delivery} =
               Verification.verify_delivery(body, headers, secret, profile,
                 delivery_id: "del-123",
                 event: "test.event",
                 source: "https://example.com"
               )

      assert delivery.provider == :webhook
      assert delivery.delivery_id == "del-123"
      assert delivery.event == "test.event"
      assert delivery.source == "https://example.com"
      assert delivery.signature_state == :verified
      assert delivery.duplicate? == false
      assert delivery.payload == %{"event" => "test"}
    end

    test "detects duplicate deliveries" do
      profile = VerificationProfile.new!(%{})
      body = ~s({"event":"test"})
      secret = "my-secret"
      signature = compute_hmac(secret, body)
      headers = %{"x-signature" => signature}

      assert {:ok, %Jido.Connect.WebhookDelivery{duplicate?: true}} =
               Verification.verify_delivery(body, headers, secret, profile,
                 delivery_id: "del-123",
                 seen_delivery_ids: ["del-123"]
               )
    end

    test "includes verification profile metadata" do
      profile =
        VerificationProfile.new!(%{
          signature_header: "x-hub-signature-256",
          digest_prefix: "sha256="
        })

      body = ~s({"event":"test"})
      secret = "my-secret"
      hex = compute_hmac(secret, body)
      signature = "sha256=#{hex}"
      headers = %{"x-hub-signature-256" => signature}

      assert {:ok, delivery} =
               Verification.verify_delivery(body, headers, secret, profile)

      assert delivery.metadata.profile.signature_header == "x-hub-signature-256"
      assert delivery.metadata.profile.digest_prefix == "sha256="
    end
  end

  describe "duplicate?/2" do
    test "returns true for seen delivery IDs" do
      assert Verification.duplicate?("del-1", ["del-1", "del-2"])
    end

    test "returns false for new delivery IDs" do
      refute Verification.duplicate?("del-3", ["del-1", "del-2"])
    end

    test "returns false for nil delivery ID" do
      refute Verification.duplicate?(nil, ["del-1"])
    end
  end

  defp compute_hmac(secret, body) do
    :crypto.mac(:hmac, :sha256, secret, body)
    |> Base.encode16(case: :lower)
  end
end
