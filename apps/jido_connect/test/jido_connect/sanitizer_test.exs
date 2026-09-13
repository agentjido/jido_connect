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

  test "redacts keyword and header pairs in both profiles" do
    value = [access_token: "secret-token", safe: "visible"]
    headers = [{"authorization", "Bearer secret-header"}]

    assert [%{"__type__" => "tuple", "items" => ["access_token", "[redacted]"]}, _] =
             Sanitizer.sanitize(value, :transport)

    for profile <- [:telemetry, :transport] do
      sanitized = Sanitizer.sanitize(%{options: value, headers: headers}, profile)

      refute inspect(sanitized) =~ "secret-token"
      refute inspect(sanitized) =~ "secret-header"
      assert inspect(sanitized) =~ "visible"
      assert inspect(sanitized) =~ "[redacted]"
    end
  end

  test "recursively redacts maps inside tuples" do
    value = {:transport_error, %{access_token: "secret-token", safe: "visible"}}

    for profile <- [:telemetry, :transport] do
      sanitized = Sanitizer.sanitize(value, profile)

      refute inspect(sanitized) =~ "secret-token"
      assert inspect(sanitized) =~ "visible"
      assert inspect(sanitized) =~ "[redacted]"
    end
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
