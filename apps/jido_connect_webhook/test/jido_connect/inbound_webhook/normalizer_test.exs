defmodule Jido.Connect.InboundWebhook.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.InboundWebhook.Normalizer
  alias Jido.Connect.WebhookDelivery

  # ---------------------------------------------------------------------------
  # normalize_signal/1
  # ---------------------------------------------------------------------------

  describe "normalize_signal/1" do
    test "normalizes a basic delivery into signal shape" do
      delivery = build_delivery()

      assert {:ok, signal} = Normalizer.normalize_signal(delivery)

      assert signal.delivery_id == "del-001"
      assert signal.event == "test.event"
      assert signal.source == "https://example.com"
      assert signal.duplicate? == false
      assert is_map(signal.headers)
      assert is_map(signal.payload)
    end

    test "includes sanitized headers" do
      delivery =
        build_delivery(%{
          headers: %{
            "content-type" => "application/json",
            "x-signature" => "secret-hmac-value",
            "x-request-id" => "req-42"
          }
        })

      assert {:ok, signal} = Normalizer.normalize_signal(delivery)

      assert signal.headers["content-type"] == "application/json"
      assert signal.headers["x-signature"] == "[redacted]"
      assert signal.headers["x-request-id"] == "req-42"
    end

    test "redacts authorization headers" do
      delivery =
        build_delivery(%{
          headers: %{
            "authorization" => "Bearer tok-secret",
            "content-type" => "application/json"
          }
        })

      assert {:ok, signal} = Normalizer.normalize_signal(delivery)

      assert signal.headers["authorization"] == "[redacted]"
      assert signal.headers["content-type"] == "application/json"
    end

    test "includes payload as-is" do
      payload = %{"action" => "created", "resource" => %{"id" => 42}}

      delivery = build_delivery(%{payload: payload})

      assert {:ok, signal} = Normalizer.normalize_signal(delivery)
      assert signal.payload == payload
    end

    test "includes query parameters from metadata" do
      delivery =
        build_delivery(%{
          metadata: %{query: %{"page" => "1", "per_page" => "25"}}
        })

      assert {:ok, signal} = Normalizer.normalize_signal(delivery)
      assert signal.query == %{"page" => "1", "per_page" => "25"}
    end

    test "includes query parameters from string-keyed metadata" do
      delivery =
        build_delivery(%{
          metadata: %{"query" => %{"filter" => "active"}}
        })

      assert {:ok, signal} = Normalizer.normalize_signal(delivery)
      assert signal.query == %{"filter" => "active"}
    end

    test "query is absent when not in metadata" do
      delivery = build_delivery()

      assert {:ok, signal} = Normalizer.normalize_signal(delivery)
      # Data.compact removes nil values
      refute Map.has_key?(signal, :query)
    end

    test "includes delivery summary" do
      delivery = build_delivery()

      assert {:ok, signal} = Normalizer.normalize_signal(delivery)

      assert is_map(signal.delivery)
      assert signal.delivery.provider == :webhook
      assert signal.delivery.id == "del-001"
      assert signal.delivery.duplicate? == false
    end

    test "compact removes nil-valued keys" do
      delivery = build_delivery(%{event: nil, source: nil})

      assert {:ok, signal} = Normalizer.normalize_signal(delivery)
      refute Map.has_key?(signal, :event)
      refute Map.has_key?(signal, :source)
    end
  end

  # ---------------------------------------------------------------------------
  # extract_headers/1
  # ---------------------------------------------------------------------------

  describe "extract_headers/1" do
    test "returns sanitized headers map" do
      delivery =
        build_delivery(%{
          headers: %{
            "content-type" => "application/json",
            "x-signature" => "should-be-redacted"
          }
        })

      headers = Normalizer.extract_headers(delivery)

      assert headers["content-type"] == "application/json"
      assert headers["x-signature"] == "[redacted]"
    end

    test "returns empty map when headers are nil" do
      delivery = build_delivery(%{headers: nil})

      headers = Normalizer.extract_headers(delivery)
      assert headers == %{}
    end
  end

  # ---------------------------------------------------------------------------
  # extract_query/1
  # ---------------------------------------------------------------------------

  describe "extract_query/1" do
    test "extracts atom-keyed query from metadata" do
      delivery = build_delivery(%{metadata: %{query: %{"q" => "test"}}})

      assert Normalizer.extract_query(delivery) == %{"q" => "test"}
    end

    test "extracts string-keyed query from metadata" do
      delivery = build_delivery(%{metadata: %{"query" => %{"q" => "test"}}})

      assert Normalizer.extract_query(delivery) == %{"q" => "test"}
    end

    test "returns empty map when query absent" do
      delivery = build_delivery(%{metadata: %{}})

      assert Normalizer.extract_query(delivery) == %{}
    end

    test "returns empty map when metadata absent" do
      delivery = build_delivery(%{metadata: nil})

      assert Normalizer.extract_query(delivery) == %{}
    end
  end

  # ---------------------------------------------------------------------------
  # dedupe_key/1
  # ---------------------------------------------------------------------------

  describe "dedupe_key/1" do
    test "returns delivery ID when present" do
      delivery = build_delivery(%{delivery_id: "del-42"})

      assert Normalizer.dedupe_key(delivery) == "del-42"
    end

    test "returns composite key from event and source" do
      delivery =
        build_delivery(%{delivery_id: nil, event: "created", source: "https://example.com"})

      assert Normalizer.dedupe_key(delivery) == "created:https://example.com"
    end

    test "returns nil when no delivery ID, event, or source" do
      delivery = build_delivery(%{delivery_id: nil, event: nil, source: nil})

      assert Normalizer.dedupe_key(delivery) == nil
    end

    test "returns composite key when delivery ID is empty string" do
      delivery = build_delivery(%{delivery_id: ""})

      assert Normalizer.dedupe_key(delivery) == "test.event:https://example.com"
    end
  end

  # ---------------------------------------------------------------------------
  # delivery_summary/1
  # ---------------------------------------------------------------------------

  describe "delivery_summary/1" do
    test "returns compact delivery summary" do
      delivery = build_delivery()

      summary = Normalizer.delivery_summary(delivery)

      assert summary.provider == :webhook
      assert summary.event == "test.event"
      assert summary.id == "del-001"
      assert summary.duplicate? == false
      assert summary.signature_state == :verified
      refute is_nil(summary.received_at)
    end

    test "omits nil values" do
      delivery = build_delivery(%{delivery_id: nil, event: nil, source: nil})

      summary = Normalizer.delivery_summary(delivery)

      refute Map.has_key?(summary, :id)
      refute Map.has_key?(summary, :event)
    end
  end

  # ---------------------------------------------------------------------------
  # Header redaction patterns
  # ---------------------------------------------------------------------------

  describe "header redaction patterns" do
    test "redacts x-hub-signature headers" do
      delivery =
        build_delivery(%{
          headers: %{"x-hub-signature-256" => "sha256=abc123", "accept" => "application/json"}
        })

      assert {:ok, signal} = Normalizer.normalize_signal(delivery)
      assert signal.headers["x-hub-signature-256"] == "[redacted]"
      assert signal.headers["accept"] == "application/json"
    end

    test "redacts x-slack-signature headers" do
      delivery =
        build_delivery(%{
          headers: %{"x-slack-signature" => "v0=abc", "user-agent" => "Slack"}
        })

      assert {:ok, signal} = Normalizer.normalize_signal(delivery)
      assert signal.headers["x-slack-signature"] == "[redacted]"
      assert signal.headers["user-agent"] == "Slack"
    end

    test "redacts cookie headers" do
      delivery =
        build_delivery(%{
          headers: %{"cookie" => "session=abc123", "host" => "example.com"}
        })

      assert {:ok, signal} = Normalizer.normalize_signal(delivery)
      assert signal.headers["cookie"] == "[redacted]"
      assert signal.headers["host"] == "example.com"
    end

    test "handles non-string header values without redacting" do
      delivery =
        build_delivery(%{
          headers: %{"x-custom" => 12345}
        })

      assert {:ok, signal} = Normalizer.normalize_signal(delivery)
      assert signal.headers["x-custom"] == 12345
    end
  end

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  describe "fixture: typical HMAC delivery" do
    test "normalizes a typical HMAC-signed delivery" do
      delivery = hmac_delivery_fixture()

      assert {:ok, signal} = Normalizer.normalize_signal(delivery)

      assert signal.delivery_id == "evt-hmac-001"
      assert signal.event == "order.created"
      assert signal.duplicate? == false
      assert signal.headers["content-type"] == "application/json"
      assert signal.headers["x-signature"] == "[redacted]"
      assert signal.payload["order_id"] == "ORD-123"
      assert signal.payload["status"] == "created"
    end
  end

  describe "fixture: bearer token delivery" do
    test "normalizes a bearer-authenticated delivery" do
      delivery = bearer_delivery_fixture()

      assert {:ok, signal} = Normalizer.normalize_signal(delivery)

      assert signal.delivery_id == "evt-bearer-001"
      assert signal.headers["authorization"] == "[redacted]"
      assert signal.payload["type"] == "notification"
    end
  end

  describe "fixture: unsigned dev delivery" do
    test "normalizes an unsigned delivery with query params" do
      delivery = unsigned_delivery_fixture()

      assert {:ok, signal} = Normalizer.normalize_signal(delivery)

      assert signal.delivery_id == "evt-unsigned-001"
      assert signal.query["source"] == "test"
      assert signal.query["env"] == "dev"
      assert signal.payload["action"] == "ping"
    end
  end

  describe "fixture: duplicate delivery" do
    test "marks duplicate delivery in signal" do
      delivery = duplicate_delivery_fixture()

      assert {:ok, signal} = Normalizer.normalize_signal(delivery)

      assert signal.duplicate? == true
      assert signal.delivery.duplicate? == true
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers / Fixtures
  # ---------------------------------------------------------------------------

  defp build_delivery(overrides \\ %{}) do
    defaults = %{
      delivery_id: "del-001",
      event: "test.event",
      source: "https://example.com",
      duplicate?: false,
      headers: %{"content-type" => "application/json"},
      payload: %{"event" => "test"},
      metadata: %{}
    }

    attrs = Map.merge(defaults, overrides)
    now = DateTime.utc_now()

    WebhookDelivery.new!(
      Map.merge(attrs, %{
        provider: :webhook,
        signature_state: :verified,
        received_at: now
      })
    )
  end

  defp hmac_delivery_fixture do
    build_delivery(%{
      delivery_id: "evt-hmac-001",
      event: "order.created",
      source: "https://shop.example.com/webhooks",
      headers: %{
        "content-type" => "application/json",
        "x-signature" => "sha256=abcdef1234567890",
        "x-delivery-id" => "evt-hmac-001",
        "x-request-id" => "req-001"
      },
      payload: %{
        "order_id" => "ORD-123",
        "status" => "created",
        "customer" => %{"email" => "customer@example.com"}
      },
      metadata: %{
        signature: "[redacted]",
        timestamp: "1_700_000_000",
        profile: %{
          mode: :hmac,
          signature_header: "x-signature",
          digest_prefix: "sha256="
        }
      }
    })
  end

  defp bearer_delivery_fixture do
    build_delivery(%{
      delivery_id: "evt-bearer-001",
      event: "notification.sent",
      source: "https://notify.example.com",
      headers: %{
        "authorization" => "Bearer tok-super-secret-value",
        "content-type" => "application/json",
        "x-request-id" => "req-bearer-001"
      },
      payload: %{
        "type" => "notification",
        "recipient" => "user-42"
      },
      metadata: %{
        profile: %{mode: :bearer, signature_header: "authorization"}
      }
    })
  end

  defp unsigned_delivery_fixture do
    build_delivery(%{
      delivery_id: "evt-unsigned-001",
      event: "ping",
      source: "https://dev.local/webhooks",
      headers: %{
        "content-type" => "application/json"
      },
      payload: %{"action" => "ping"},
      metadata: %{
        query: %{"source" => "test", "env" => "dev"},
        profile: %{mode: :unsigned}
      }
    })
  end

  defp duplicate_delivery_fixture do
    build_delivery(%{
      delivery_id: "evt-dup-001",
      event: "order.created",
      source: "https://shop.example.com/webhooks",
      duplicate?: true,
      headers: %{
        "content-type" => "application/json",
        "x-signature" => "sha256=abcdef1234567890"
      },
      payload: %{"order_id" => "ORD-123", "status" => "created"},
      metadata: %{}
    })
  end
end
