defmodule Jido.Connect.SanitizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.{CredentialLease, Sanitizer}

  test "redacts sensitive keys for telemetry and transport profiles" do
    value = %{
      :access_token => "secret-token",
      :api_token => "secret-api-token",
      "client_secret" => "secret-client",
      "x-hub-signature-256" => "sha256=secret-signature",
      nested: %{refresh_token: "secret-refresh", ok: true}
    }

    assert %{
             :access_token => "[redacted]",
             :api_token => "[redacted]",
             "client_secret" => "[redacted]",
             "x-hub-signature-256" => "[redacted]",
             nested: %{refresh_token: "[redacted]", ok: true}
           } = Sanitizer.sanitize(value, :telemetry)

    assert %{
             "access_token" => "[redacted]",
             "api_token" => "[redacted]",
             "client_secret" => "[redacted]",
             "nested" => %{"refresh_token" => "[redacted]", "ok" => true},
             "x-hub-signature-256" => "[redacted]"
           } = Sanitizer.sanitize(value, :transport)
  end

  test "bounds large values and converts transport payloads to public-safe shapes" do
    sanitized =
      Sanitizer.sanitize(
        %{
          tuple: {:ok, :value},
          payload: String.duplicate("a", 20),
          values: Enum.to_list(1..5)
        },
        :transport,
        max_binary: 8,
        max_collection: 3
      )

    assert sanitized["tuple"] == %{"__type__" => "tuple", "items" => ["ok", "value"]}
    assert sanitized["payload"] == "aaaaaaaa...[truncated 12 bytes]"
    assert sanitized["values"] == [1, 2, 3, "[truncated 2 items]"]
  end

  test "summarizes credential lease structs without exposing credential material" do
    lease =
      CredentialLease.new!(%{
        connection_id: "conn_1",
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second),
        fields: %{access_token: "secret-token"},
        metadata: %{private_key: "secret-key", installation_id: 1}
      })

    sanitized = Sanitizer.sanitize(lease, :transport)

    assert sanitized["connection_id"] == "conn_1"
    assert sanitized["fields"] == "[redacted]"
    assert sanitized["metadata"]["private_key"] == "[redacted]"
    refute inspect(sanitized) =~ "secret-token"
    refute inspect(sanitized) =~ "secret-key"
  end
end
