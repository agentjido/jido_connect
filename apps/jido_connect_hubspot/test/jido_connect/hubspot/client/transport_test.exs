defmodule Jido.Connect.HubSpot.Client.TransportTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.HubSpot.Client.Transport

  test "base_url returns default HubSpot API URL" do
    assert Transport.base_url() == "https://api.hubapi.com"
  end

  test "api_request builds a bearer request" do
    request = Transport.api_request("test-token")

    assert %Req.Request{} = request
    assert request.options.base_url == "https://api.hubapi.com"
    assert request.headers["authorization"] == ["Bearer test-token"]
    assert request.headers["accept"] == ["application/json"]
  end

  test "api_request accepts custom base URL" do
    request = Transport.api_request("test-token", base_url: "https://custom.example.com")

    assert %Req.Request{} = request
    assert request.options.base_url == "https://custom.example.com"
  end

  test "handle_error_response normalizes HTTP error" do
    response = {:ok, %{status: 401, body: %{"message" => "Unauthorized"}}}

    assert {:error, %Jido.Connect.Error.ProviderError{provider: :hubspot}} =
             Transport.handle_error_response(response)
  end

  test "handle_error_response normalizes non-map response" do
    response = {:error, :timeout}

    assert {:error, %Jido.Connect.Error.ProviderError{provider: :hubspot}} =
             Transport.handle_error_response(response)
  end

  test "invalid_success_response returns provider error" do
    assert {:error,
            %Jido.Connect.Error.ProviderError{provider: :hubspot, reason: :invalid_response}} =
             Transport.invalid_success_response("bad response", %{"foo" => "bar"})
  end
end
