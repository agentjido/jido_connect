defmodule Jido.Connect.InboundWebhook.VerificationTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.InboundWebhook.Verification
  alias Jido.Connect.InboundWebhook.VerificationProfile

  # ---------------------------------------------------------------------------
  # parse_headers/2
  # ---------------------------------------------------------------------------

  describe "parse_headers/2" do
    test "extracts signature from default header" do
      profile = VerificationProfile.new!(%{})
      headers = %{"x-signature" => "abc123"}

      assert %{signature: "abc123", timestamp: nil, replay_id: nil} =
               Verification.parse_headers(headers, profile)
    end

    test "extracts signature and timestamp from custom headers" do
      profile =
        VerificationProfile.new!(%{
          signature_header: "x-hub-signature-256",
          timestamp_header: "x-timestamp"
        })

      headers = %{"x-hub-signature-256" => "sha256=abc", "x-timestamp" => "1700000000"}

      assert %{signature: "sha256=abc", timestamp: "1700000000", replay_id: nil} =
               Verification.parse_headers(headers, profile)
    end

    test "returns nil when headers are missing" do
      profile = VerificationProfile.new!(%{})
      headers = %{}

      assert %{signature: nil, timestamp: nil, replay_id: nil} =
               Verification.parse_headers(headers, profile)
    end

    test "normalizes header keys case-insensitively" do
      profile = VerificationProfile.new!(%{})
      headers = %{"X-Signature" => "abc123"}

      assert %{signature: "abc123"} = Verification.parse_headers(headers, profile)
    end

    test "extracts replay ID from configured header" do
      profile =
        VerificationProfile.new!(%{
          replay_id_header: "x-delivery-id"
        })

      headers = %{"x-signature" => "abc", "x-delivery-id" => "evt-42"}

      assert %{replay_id: "evt-42"} = Verification.parse_headers(headers, profile)
    end

    test "replay ID is nil when header absent" do
      profile =
        VerificationProfile.new!(%{
          replay_id_header: "x-delivery-id"
        })

      headers = %{"x-signature" => "abc"}

      assert %{replay_id: nil} = Verification.parse_headers(headers, profile)
    end

    test "replay ID is nil when replay_id_header not configured" do
      profile = VerificationProfile.new!(%{})
      headers = %{"x-delivery-id" => "evt-42"}

      assert %{replay_id: nil} = Verification.parse_headers(headers, profile)
    end
  end

  # ---------------------------------------------------------------------------
  # verify_signature/4 (HMAC)
  # ---------------------------------------------------------------------------

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

  # ---------------------------------------------------------------------------
  # verify_bearer/2
  # ---------------------------------------------------------------------------

  describe "verify_bearer/2" do
    test "accepts matching bearer token" do
      assert :ok = Verification.verify_bearer("tok-abc123", "tok-abc123")
    end

    test "rejects mismatched bearer token" do
      assert {:error, %Jido.Connect.Error.AuthError{reason: :invalid_bearer_token}} =
               Verification.verify_bearer("wrong-token", "expected-token")
    end

    test "rejects nil expected token" do
      assert {:error, %Jido.Connect.Error.AuthError{reason: :missing_bearer_token}} =
               Verification.verify_bearer("some-token", nil)
    end

    test "rejects empty expected token" do
      assert {:error, %Jido.Connect.Error.AuthError{reason: :missing_bearer_token}} =
               Verification.verify_bearer("some-token", "")
    end

    test "rejects nil header token" do
      assert {:error, %Jido.Connect.Error.AuthError{reason: :missing_bearer_token}} =
               Verification.verify_bearer(nil, "expected-token")
    end

    test "rejects empty header token" do
      assert {:error, %Jido.Connect.Error.AuthError{reason: :missing_bearer_token}} =
               Verification.verify_bearer("", "expected-token")
    end
  end

  # ---------------------------------------------------------------------------
  # verify_by_mode/4
  # ---------------------------------------------------------------------------

  describe "verify_by_mode/4" do
    test "dispatches to HMAC for :hmac mode" do
      profile = VerificationProfile.new!(%{mode: :hmac})
      body = ~s({"event":"test"})
      secret = "my-secret"
      signature = compute_hmac(secret, body)

      assert :ok = Verification.verify_by_mode(body, signature, secret, profile)
    end

    test "dispatches to bearer for :bearer mode" do
      profile = VerificationProfile.new!(%{mode: :bearer})

      assert :ok = Verification.verify_by_mode("body", "my-token", "my-token", profile)
    end

    test "dispatches to bearer and rejects mismatch" do
      profile = VerificationProfile.new!(%{mode: :bearer})

      assert {:error, %Jido.Connect.Error.AuthError{reason: :invalid_bearer_token}} =
               Verification.verify_by_mode("body", "wrong", "expected", profile)
    end

    test "always returns :ok for :unsigned mode" do
      profile = VerificationProfile.new!(%{mode: :unsigned})

      assert :ok = Verification.verify_by_mode("body", nil, nil, profile)
    end

    test "unsigned mode ignores invalid signature" do
      profile = VerificationProfile.new!(%{mode: :unsigned})

      assert :ok = Verification.verify_by_mode("body", "bad-sig", nil, profile)
    end
  end

  # ---------------------------------------------------------------------------
  # verify_request/5
  # ---------------------------------------------------------------------------

  describe "verify_request/5 (HMAC mode)" do
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

  describe "verify_request/5 (bearer mode)" do
    test "verifies valid request with correct bearer token" do
      profile = VerificationProfile.new!(%{mode: :bearer, signature_header: "authorization"})
      body = ~s({"event":"test"})
      headers = %{"authorization" => "my-static-token"}

      assert {:ok, %{"event" => "test"}} =
               Verification.verify_request(body, headers, "my-static-token", profile)
    end

    test "rejects request with wrong bearer token" do
      profile = VerificationProfile.new!(%{mode: :bearer, signature_header: "authorization"})
      body = ~s({"event":"test"})
      headers = %{"authorization" => "wrong-token"}

      assert {:error, %Jido.Connect.Error.AuthError{reason: :invalid_bearer_token}} =
               Verification.verify_request(body, headers, "expected-token", profile)
    end
  end

  describe "verify_request/5 (unsigned mode)" do
    test "accepts any request in unsigned dev mode" do
      profile = VerificationProfile.new!(%{mode: :unsigned})
      body = ~s({"event":"test"})
      headers = %{}

      assert {:ok, %{"event" => "test"}} =
               Verification.verify_request(body, headers, nil, profile)
    end

    test "still validates timestamp in unsigned mode when configured" do
      profile =
        VerificationProfile.new!(%{
          mode: :unsigned,
          timestamp_header: "x-timestamp",
          timestamp_tolerance_seconds: 300
        })

      body = ~s({"event":"test"})
      now = 1_700_001_000

      headers = %{
        "x-timestamp" => "1700000000"
      }

      assert {:error, %Jido.Connect.Error.AuthError{reason: :stale_timestamp}} =
               Verification.verify_request(body, headers, nil, profile, now: now)
    end

    test "still validates JSON body in unsigned mode" do
      profile = VerificationProfile.new!(%{mode: :unsigned})
      body = "not json"
      headers = %{}

      assert {:error, %Jido.Connect.Error.ProviderError{provider: :webhook}} =
               Verification.verify_request(body, headers, nil, profile)
    end
  end

  # ---------------------------------------------------------------------------
  # verify_delivery/5
  # ---------------------------------------------------------------------------

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

    test "redacts signature in metadata" do
      profile = VerificationProfile.new!(%{})
      body = ~s({"event":"test"})
      secret = "my-secret"
      signature = compute_hmac(secret, body)
      headers = %{"x-signature" => signature}

      assert {:ok, delivery} =
               Verification.verify_delivery(body, headers, secret, profile)

      assert delivery.metadata.signature == "[redacted]"
    end

    test "extracts replay ID from header when replay_id_header is configured" do
      profile =
        VerificationProfile.new!(%{
          replay_id_header: "x-delivery-id"
        })

      body = ~s({"event":"test"})
      secret = "my-secret"
      signature = compute_hmac(secret, body)
      headers = %{"x-signature" => signature, "x-delivery-id" => "evt-auto-42"}

      assert {:ok, delivery} =
               Verification.verify_delivery(body, headers, secret, profile)

      assert delivery.delivery_id == "evt-auto-42"
      assert delivery.metadata.replay_id == "evt-auto-42"
    end

    test "opts delivery_id overrides header replay ID" do
      profile =
        VerificationProfile.new!(%{
          replay_id_header: "x-delivery-id"
        })

      body = ~s({"event":"test"})
      secret = "my-secret"
      signature = compute_hmac(secret, body)
      headers = %{"x-signature" => signature, "x-delivery-id" => "evt-auto-42"}

      assert {:ok, delivery} =
               Verification.verify_delivery(body, headers, secret, profile,
                 delivery_id: "manual-del-99"
               )

      assert delivery.delivery_id == "manual-del-99"
    end

    test "detects duplicate from header-extracted replay ID" do
      profile =
        VerificationProfile.new!(%{
          replay_id_header: "x-delivery-id"
        })

      body = ~s({"event":"test"})
      secret = "my-secret"
      signature = compute_hmac(secret, body)
      headers = %{"x-signature" => signature, "x-delivery-id" => "evt-dup-1"}

      assert {:ok, %Jido.Connect.WebhookDelivery{duplicate?: true}} =
               Verification.verify_delivery(body, headers, secret, profile,
                 seen_delivery_ids: ["evt-dup-1"]
               )
    end

    test "works with bearer mode" do
      profile =
        VerificationProfile.new!(%{
          mode: :bearer,
          signature_header: "authorization"
        })

      body = ~s({"event":"test"})
      headers = %{"authorization" => "tok-123"}

      assert {:ok, %Jido.Connect.WebhookDelivery{signature_state: :verified}} =
               Verification.verify_delivery(body, headers, "tok-123", profile)
    end

    test "works with unsigned mode" do
      profile = VerificationProfile.new!(%{mode: :unsigned})
      body = ~s({"event":"test"})
      headers = %{}

      assert {:ok, %Jido.Connect.WebhookDelivery{signature_state: :verified}} =
               Verification.verify_delivery(body, headers, nil, profile)
    end

    test "includes mode in profile metadata" do
      profile = VerificationProfile.new!(%{mode: :bearer, signature_header: "authorization"})
      body = ~s({"event":"test"})
      headers = %{"authorization" => "tok-123"}

      assert {:ok, delivery} =
               Verification.verify_delivery(body, headers, "tok-123", profile)

      assert delivery.metadata.profile.mode == :bearer
      assert delivery.metadata.profile.replay_id_header == nil
    end
  end

  # ---------------------------------------------------------------------------
  # duplicate?/2
  # ---------------------------------------------------------------------------

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

  # ---------------------------------------------------------------------------
  # extract_replay_id/2
  # ---------------------------------------------------------------------------

  describe "extract_replay_id/2" do
    test "extracts replay ID from configured header" do
      profile = VerificationProfile.new!(%{replay_id_header: "x-delivery-id"})
      headers = %{"x-delivery-id" => "evt-42"}

      assert Verification.extract_replay_id(headers, profile) == "evt-42"
    end

    test "returns nil when header is absent" do
      profile = VerificationProfile.new!(%{replay_id_header: "x-delivery-id"})
      headers = %{}

      assert Verification.extract_replay_id(headers, profile) == nil
    end

    test "returns nil when replay_id_header not configured" do
      profile = VerificationProfile.new!(%{})
      headers = %{"x-delivery-id" => "evt-42"}

      assert Verification.extract_replay_id(headers, profile) == nil
    end

    test "is case-insensitive" do
      profile = VerificationProfile.new!(%{replay_id_header: "x-delivery-id"})
      headers = %{"X-Delivery-Id" => "evt-42"}

      assert Verification.extract_replay_id(headers, profile) == "evt-42"
    end
  end

  # ---------------------------------------------------------------------------
  # redacted_error/1
  # ---------------------------------------------------------------------------

  describe "redacted_error/1" do
    test "returns a map with type, message, reason, and sanitized details" do
      error =
        Jido.Connect.Error.auth("Signature mismatch",
          reason: :invalid_signature,
          details: %{secret: "sensitive-secret-value", hint: "visible"}
        )

      redacted = Verification.redacted_error(error)

      assert redacted.type == :auth_error
      assert redacted.message == "Signature mismatch"
      assert redacted.reason == :invalid_signature
      assert redacted.details["secret"] == "[redacted]"
      assert redacted.details["hint"] == "visible"
    end

    test "redacts signature from error details" do
      error =
        Jido.Connect.Error.auth("Bad sig",
          reason: :invalid_signature,
          details: %{signature: "hmac-sha256-abc123", other: "ok"}
        )

      redacted = Verification.redacted_error(error)

      assert redacted.details["signature"] == "[redacted]"
      assert redacted.details["other"] == "ok"
    end

    test "redacts token from error details" do
      error =
        Jido.Connect.Error.auth("Bad token",
          reason: :invalid_bearer_token,
          details: %{token: "super-secret-token", public_info: "ok"}
        )

      redacted = Verification.redacted_error(error)

      assert redacted.details["token"] == "[redacted]"
      assert redacted.details["public_info"] == "ok"
    end

    test "handles provider errors" do
      error =
        Jido.Connect.Error.provider("Invalid JSON",
          provider: :webhook,
          reason: :invalid_payload,
          details: %{body_summary: "not json"}
        )

      redacted = Verification.redacted_error(error)

      assert redacted.type == :provider_error
      assert redacted.message == "Invalid JSON"
    end

    test "handles errors with empty details" do
      error = Jido.Connect.Error.auth("Auth failed", reason: :missing_secret)

      redacted = Verification.redacted_error(error)

      assert is_map(redacted.details)
    end
  end

  # ---------------------------------------------------------------------------
  # Timestamp tolerance edge cases
  # ---------------------------------------------------------------------------

  describe "timestamp tolerance edge cases" do
    test "accepts request at exact tolerance boundary" do
      profile =
        VerificationProfile.new!(%{
          mode: :unsigned,
          timestamp_header: "x-timestamp",
          timestamp_tolerance_seconds: 300
        })

      body = ~s({"event":"test"})
      now = 1_700_000_300

      headers = %{"x-timestamp" => "1700000000"}

      assert {:ok, _} =
               Verification.verify_request(body, headers, nil, profile, now: now)
    end

    test "rejects request one second past tolerance boundary" do
      profile =
        VerificationProfile.new!(%{
          mode: :unsigned,
          timestamp_header: "x-timestamp",
          timestamp_tolerance_seconds: 300
        })

      body = ~s({"event":"test"})
      now = 1_700_000_301

      headers = %{"x-timestamp" => "1700000000"}

      assert {:error, %Jido.Connect.Error.AuthError{reason: :stale_timestamp}} =
               Verification.verify_request(body, headers, nil, profile, now: now)
    end

    test "rejects non-numeric timestamp" do
      profile =
        VerificationProfile.new!(%{
          mode: :unsigned,
          timestamp_header: "x-timestamp",
          timestamp_tolerance_seconds: 300
        })

      body = ~s({"event":"test"})

      headers = %{"x-timestamp" => "not-a-number"}

      assert {:error, %Jido.Connect.Error.AuthError{reason: :invalid_timestamp}} =
               Verification.verify_request(body, headers, nil, profile)
    end

    test "skips timestamp when tolerance is nil" do
      profile =
        VerificationProfile.new!(%{
          mode: :unsigned,
          timestamp_header: "x-timestamp",
          timestamp_tolerance_seconds: nil
        })

      body = ~s({"event":"test"})

      headers = %{"x-timestamp" => "0"}

      assert {:ok, _} =
               Verification.verify_request(body, headers, nil, profile)
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp compute_hmac(secret, body) do
    :crypto.mac(:hmac, :sha256, secret, body)
    |> Base.encode16(case: :lower)
  end
end
