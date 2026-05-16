defmodule Jido.Connect.InboundWebhook.VerificationProfileTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.InboundWebhook.VerificationProfile

  describe "new!/1 defaults" do
    test "builds a profile with defaults" do
      profile = VerificationProfile.new!(%{})

      assert profile.mode == :hmac
      assert profile.signature_header == "x-signature"
      assert profile.timestamp_header == nil
      assert profile.digest_prefix == ""
      assert profile.timestamp_tolerance_seconds == nil
      assert profile.replay_id_header == nil
    end
  end

  describe "new!/1 HMAC profiles" do
    test "builds a profile with custom signature header" do
      profile = VerificationProfile.new!(%{signature_header: "x-hub-signature-256"})

      assert profile.mode == :hmac
      assert profile.signature_header == "x-hub-signature-256"
    end

    test "builds a profile with GitHub-like settings" do
      profile =
        VerificationProfile.new!(%{
          signature_header: "x-hub-signature-256",
          digest_prefix: "sha256="
        })

      assert profile.signature_header == "x-hub-signature-256"
      assert profile.digest_prefix == "sha256="
    end

    test "builds a profile with Slack-like settings" do
      profile =
        VerificationProfile.new!(%{
          signature_header: "x-slack-signature",
          timestamp_header: "x-slack-request-timestamp",
          digest_prefix: "v0=",
          timestamp_tolerance_seconds: 300
        })

      assert profile.signature_header == "x-slack-signature"
      assert profile.timestamp_header == "x-slack-request-timestamp"
      assert profile.digest_prefix == "v0="
      assert profile.timestamp_tolerance_seconds == 300
    end
  end

  describe "new!/1 bearer profiles" do
    test "builds a bearer profile with default signature header" do
      profile = VerificationProfile.new!(%{mode: :bearer})

      assert profile.mode == :bearer
      assert profile.signature_header == "x-signature"
    end

    test "builds a bearer profile with authorization header" do
      profile =
        VerificationProfile.new!(%{
          mode: :bearer,
          signature_header: "authorization"
        })

      assert profile.mode == :bearer
      assert profile.signature_header == "authorization"
    end
  end

  describe "new!/1 unsigned profiles" do
    test "builds an unsigned dev-mode profile" do
      profile = VerificationProfile.new!(%{mode: :unsigned})

      assert profile.mode == :unsigned
      assert profile.signature_header == "x-signature"
    end
  end

  describe "new!/1 replay ID header" do
    test "builds a profile with replay_id_header" do
      profile =
        VerificationProfile.new!(%{
          replay_id_header: "x-delivery-id"
        })

      assert profile.replay_id_header == "x-delivery-id"
    end

    test "replay_id_header defaults to nil" do
      profile = VerificationProfile.new!(%{})
      assert profile.replay_id_header == nil
    end
  end

  describe "new!/1 validation" do
    test "raises on invalid input" do
      assert_raise Zoi.ParseError, fn ->
        VerificationProfile.new!(%{signature_header: 123})
      end
    end

    test "raises on invalid mode" do
      assert_raise Zoi.ParseError, fn ->
        VerificationProfile.new!(%{mode: :oauth})
      end
    end
  end

  describe "new/1" do
    test "returns error tuple on invalid input" do
      assert {:error, [%Zoi.Error{}]} = VerificationProfile.new(%{signature_header: 123})
    end
  end

  describe "schema/0" do
    test "returns the Zoi schema" do
      schema = VerificationProfile.schema()
      refute is_nil(schema)
    end
  end
end
