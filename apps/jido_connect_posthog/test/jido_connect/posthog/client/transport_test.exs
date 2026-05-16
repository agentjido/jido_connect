defmodule Jido.Connect.PostHog.Client.TransportTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error
  alias Jido.Connect.PostHog.Client.Transport

  test "base_url returns default PostHog API base URL" do
    assert Transport.base_url() == "https://app.posthog.com"
  end

  test "request builds a bearer request" do
    request = Transport.request("test-api-key")

    assert %Req.Request{} = request
    assert request.options.base_url == "https://app.posthog.com"
    assert request.headers["authorization"] == ["Bearer test-api-key"]
    assert request.headers["accept"] == ["application/json"]
    assert request.headers["content-type"] == ["application/json"]
  end

  test "request accepts custom base URL via opts" do
    request = Transport.request("test-api-key", base_url: "https://posthog.example.com")
    assert request.options.base_url == "https://posthog.example.com"
  end

  test "request uses configured application env base URL" do
    original = Application.get_env(:jido_connect_posthog, :posthog_api_base_url)

    try do
      Application.put_env(:jido_connect_posthog, :posthog_api_base_url, "https://eu.posthog.com")
      assert Transport.base_url() == "https://eu.posthog.com"

      request = Transport.request("test-api-key")
      assert request.options.base_url == "https://eu.posthog.com"
    after
      if original do
        Application.put_env(:jido_connect_posthog, :posthog_api_base_url, original)
      else
        Application.delete_env(:jido_connect_posthog, :posthog_api_base_url)
      end
    end
  end

  test "handle_error_response normalizes HTTP error bodies" do
    assert {:error, %Error.ProviderError{provider: :posthog, reason: :http_error, status: 401}} =
             Transport.handle_error_response(
               {:ok, %{status: 401, body: %{"detail" => "Invalid token."}}}
             )
  end

  test "handle_error_response extracts error messages from detail field" do
    assert {:error, %Error.ProviderError{details: %{message: "Invalid token."}}} =
             Transport.handle_error_response(
               {:ok, %{status: 401, body: %{"detail" => "Invalid token."}}}
             )
  end

  test "handle_error_response handles request errors" do
    assert {:error, %Error.ProviderError{provider: :posthog}} =
             Transport.handle_error_response({:error, :timeout})
  end

  test "invalid_success_response returns provider error" do
    assert {:error, %Error.ProviderError{provider: :posthog, reason: :invalid_response}} =
             Transport.invalid_success_response("test message", %{foo: "bar"})
  end
end
