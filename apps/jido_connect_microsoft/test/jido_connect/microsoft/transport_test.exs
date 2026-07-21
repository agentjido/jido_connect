defmodule Jido.Connect.Microsoft.TransportTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.Microsoft.Transport

  setup do
    Application.put_env(:jido_connect_microsoft, :microsoft_graph_base_url, "https://graph.test")

    on_exit(fn ->
      Application.delete_env(:jido_connect_microsoft, :microsoft_graph_base_url)
      Application.delete_env(:jido_connect_microsoft, :microsoft_req_options)
    end)
  end

  describe "request/2" do
    test "builds bearer requests with Microsoft Graph defaults" do
      request = Transport.request("token")

      assert request.options.base_url == "https://graph.test"
      assert request.headers["authorization"] == ["Bearer token"]
      assert request.headers["accept"] == ["application/json"]
    end

    test "builds requests with caller overrides" do
      Application.put_env(:jido_connect_microsoft, :microsoft_req_options, receive_timeout: 500)

      request =
        Transport.request("token",
          base_url: "https://override.test",
          req_options: [retry: false]
        )

      assert request.options.base_url == "https://override.test"
      assert request.options.receive_timeout == 500
      assert request.options.retry == false
    end

    test "uses default Graph v1.0 base URL when no config override" do
      Application.delete_env(:jido_connect_microsoft, :microsoft_graph_base_url)

      request = Transport.request("token")

      assert request.options.base_url == "https://graph.microsoft.com/v1.0"
    end

    test "merges application and caller req options with caller taking precedence" do
      Application.put_env(:jido_connect_microsoft, :microsoft_req_options,
        receive_timeout: 1000,
        retry: true
      )

      request =
        Transport.request("token",
          req_options: [retry: false, max_redirects: 3]
        )

      # Application env value preserved when caller doesn't override
      assert request.options.receive_timeout == 1000
      # Caller override takes precedence
      assert request.options.retry == false
      # Caller-only option present
      assert request.options.max_redirects == 3
    end
  end

  describe "base_url/0" do
    test "returns configured base URL" do
      assert Transport.base_url() == "https://graph.test"
    end

    test "returns default when config is cleared" do
      Application.delete_env(:jido_connect_microsoft, :microsoft_graph_base_url)
      assert Transport.base_url() == "https://graph.microsoft.com/v1.0"
    end
  end

  describe "handle_error_response/2" do
    test "normalizes error responses with nested OData error message" do
      assert {:error,
              %Error.ProviderError{
                provider: :microsoft,
                reason: :http_error,
                status: 403,
                details: %{message: "denied"}
              }} =
               Transport.handle_error_response(
                 {:ok, %{status: 403, body: %{"error" => %{"message" => "denied"}}}}
               )
    end

    test "normalizes alternate error response shapes" do
      # Atom-keyed nested error
      assert {:error, %Error.ProviderError{details: %{message: "atom denied"}}} =
               Transport.handle_error_response(
                 {:ok, %{status: 403, body: %{error: %{message: "atom denied"}}}}
               )

      # String-keyed flat error
      assert {:error, %Error.ProviderError{details: %{message: "plain denied"}}} =
               Transport.handle_error_response(
                 {:ok, %{status: 403, body: %{"error" => "plain denied"}}}
               )

      # Atom-keyed flat error
      assert {:error, %Error.ProviderError{details: %{message: "atom plain denied"}}} =
               Transport.handle_error_response(
                 {:ok, %{status: 403, body: %{error: "atom plain denied"}}}
               )
    end

    test "falls back to default message for unrecognized error shapes" do
      assert {:error,
              %Error.ProviderError{details: %{message: "Microsoft Graph API request failed"}}} =
               Transport.handle_error_response(
                 {:ok, %{status: 500, body: %{"unexpected" => true}}}
               )
    end

    test "normalizes request-level failures through shared transport" do
      assert {:error,
              %Error.ProviderError{
                provider: :microsoft,
                reason: :request_error,
                details: %{reason: :timeout}
              }} =
               Transport.handle_error_response({:error, :timeout}, message: "Microsoft timeout")
    end

    test "accepts custom message and reason overrides" do
      assert {:error, %Error.ProviderError{message: "custom msg", reason: :sync_failed}} =
               Transport.handle_error_response(
                 {:ok, %{status: 412, body: %{"error" => %{"message" => "precondition"}}}},
                 message: "custom msg",
                 reason: :sync_failed
               )
    end
  end

  describe "invalid_success_response/2" do
    test "normalizes malformed success responses as sanitized provider errors" do
      assert {:error,
              %Error.ProviderError{
                provider: :microsoft,
                reason: :invalid_response,
                details: %{body_summary: %{type: :map, keys: ["secret"]}}
              }} =
               Transport.invalid_success_response("bad response", %{
                 "secret" => "long-secret-provider-body"
               })
    end

    test "includes the raw body reference in details" do
      assert {:error, %Error.ProviderError{details: %{body_summary: %{type: :map, keys: ["x"]}}}} =
               Transport.invalid_success_response("unexpected shape", %{"x" => 1})
    end
  end

  describe "response_metadata/1" do
    test "extracts rate-limit metadata from a 429 response" do
      response =
        {:ok,
         %{
           status: 429,
           headers: %{
             "Retry-After" => "30",
             "client-request-id" => "req-123"
           }
         }}

      meta = Transport.response_metadata(response)

      assert meta.rate_limited == true
      assert meta.retry_after == 30
      assert meta.request_id == "req-123"
    end

    test "extracts metadata from a normal success response" do
      response =
        {:ok,
         %{
           status: 200,
           headers: %{
             "client-request-id" => "req-456"
           }
         }}

      meta = Transport.response_metadata(response)

      assert meta.rate_limited == false
      assert meta.request_id == "req-456"
      refute Map.has_key?(meta, :retry_after)
    end

    test "handles list headers" do
      response =
        {:ok,
         %{
           status: 429,
           headers: [
             {"Retry-After", ["25"]},
             {"client-request-id", ["abc"]}
           ]
         }}

      meta = Transport.response_metadata(response)

      assert meta.rate_limited == true
      assert meta.retry_after == 25
      assert meta.request_id == "abc"
    end

    test "returns minimal metadata for error responses" do
      meta = Transport.response_metadata({:error, :timeout})
      assert meta.rate_limited == false
    end

    test "returns empty map for unrecognized inputs" do
      assert Transport.response_metadata(nil) == %{}
    end

    test "ignores non-integer Retry-After values" do
      response =
        {:ok,
         %{
           status: 429,
           headers: %{"Retry-After" => "not-a-number"}
         }}

      meta = Transport.response_metadata(response)
      assert meta.rate_limited == true
      refute Map.has_key?(meta, :retry_after)
    end

    test "handles missing headers gracefully" do
      response = {:ok, %{status: 200, headers: %{}}}

      meta = Transport.response_metadata(response)
      assert meta.rate_limited == false
    end
  end

  describe "rate_limited?/1" do
    test "returns true for 429 responses" do
      assert Transport.rate_limited?({:ok, %{status: 429, headers: %{}}}) == true
    end

    test "returns false for non-429 responses" do
      assert Transport.rate_limited?({:ok, %{status: 200, headers: %{}}}) == false
      assert Transport.rate_limited?({:ok, %{status: 500, headers: %{}}}) == false
    end

    test "returns false for error responses" do
      assert Transport.rate_limited?({:error, :timeout}) == false
    end

    test "returns false for unexpected inputs" do
      assert Transport.rate_limited?(nil) == false
    end
  end

  describe "retryable?/1" do
    test "returns true for 429 rate-limit responses" do
      assert Transport.retryable?({:ok, %{status: 429}}) == true
    end

    test "returns true for 503 service unavailable" do
      assert Transport.retryable?({:ok, %{status: 503}}) == true
    end

    test "returns true for 504 gateway timeout" do
      assert Transport.retryable?({:ok, %{status: 504}}) == true
    end

    test "returns false for non-retryable HTTP statuses" do
      assert Transport.retryable?({:ok, %{status: 200}}) == false
      assert Transport.retryable?({:ok, %{status: 400}}) == false
      assert Transport.retryable?({:ok, %{status: 401}}) == false
      assert Transport.retryable?({:ok, %{status: 403}}) == false
      assert Transport.retryable?({:ok, %{status: 404}}) == false
      assert Transport.retryable?({:ok, %{status: 500}}) == false
    end

    test "returns true for retryable transport errors" do
      assert Transport.retryable?({:error, :timeout}) == true
      assert Transport.retryable?({:error, :connection_refused}) == true
      assert Transport.retryable?({:error, :closed}) == true
    end

    test "returns false for non-retryable transport errors" do
      assert Transport.retryable?({:error, :nxdomain}) == false
    end
  end
end
