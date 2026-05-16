defmodule Jido.Connect.Salesforce.Client.TransportTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Salesforce.Client.Transport

  test "api_version returns default Salesforce API version" do
    assert Transport.api_version() == "60.0"
  end

  test "default_instance_url returns default instance URL" do
    assert Transport.default_instance_url() == "https://login.salesforce.com"
  end

  test "rest_base builds correct REST base path" do
    assert Transport.rest_base("https://myorg.my.salesforce.com") ==
             "https://myorg.my.salesforce.com/services/data/v60.0"
  end

  test "rest_base strips trailing slash" do
    assert Transport.rest_base("https://myorg.my.salesforce.com/") ==
             "https://myorg.my.salesforce.com/services/data/v60.0"
  end

  test "api_request builds a bearer request with instance URL" do
    request =
      Transport.api_request("https://myorg.my.salesforce.com", "test-token")

    assert %Req.Request{} = request
    assert request.options.base_url == "https://myorg.my.salesforce.com/services/data/v60.0"
    assert request.headers["authorization"] == ["Bearer test-token"]
    assert request.headers["accept"] == ["application/json"]
  end

  test "handle_error_response normalizes HTTP error" do
    response = {:ok, %{status: 401, body: %{"message" => "Session expired"}}}

    assert {:error, %Jido.Connect.Error.ProviderError{provider: :salesforce}} =
             Transport.handle_error_response(response)
  end

  test "handle_error_response normalizes non-map response" do
    response = {:error, :timeout}

    assert {:error, %Jido.Connect.Error.ProviderError{provider: :salesforce}} =
             Transport.handle_error_response(response)
  end

  test "invalid_success_response returns provider error" do
    assert {:error,
            %Jido.Connect.Error.ProviderError{provider: :salesforce, reason: :invalid_response}} =
             Transport.invalid_success_response("bad response", %{"foo" => "bar"})
  end
end
