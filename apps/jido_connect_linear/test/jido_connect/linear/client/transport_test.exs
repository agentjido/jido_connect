defmodule Jido.Connect.Linear.Client.TransportTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error
  alias Jido.Connect.Linear.Client.Transport

  test "base_url returns default Linear API base URL" do
    assert Transport.base_url() == "https://api.linear.app"
  end

  test "request builds a bearer request" do
    request = Transport.request("test-token")

    assert %Req.Request{} = request
    assert request.options.base_url == "https://api.linear.app"
    assert request.headers["authorization"] == ["Bearer test-token"]
    assert request.headers["accept"] == ["application/json"]
    assert request.headers["content-type"] == ["application/json"]
  end

  test "request accepts custom base URL via opts" do
    request = Transport.request("test-token", base_url: "https://custom.linear.app")
    assert request.options.base_url == "https://custom.linear.app"
  end

  test "request uses configured application env base URL" do
    original = Application.get_env(:jido_connect_linear, :linear_api_base_url)

    try do
      Application.put_env(:jido_connect_linear, :linear_api_base_url, "https://env.linear.app")
      assert Transport.base_url() == "https://env.linear.app"

      request = Transport.request("test-token")
      assert request.options.base_url == "https://env.linear.app"
    after
      if original do
        Application.put_env(:jido_connect_linear, :linear_api_base_url, original)
      else
        Application.delete_env(:jido_connect_linear, :linear_api_base_url)
      end
    end
  end

  test "handle_error_response normalizes HTTP error bodies" do
    assert {:error, %Error.ProviderError{provider: :linear, reason: :http_error, status: 400}} =
             Transport.handle_error_response(
               {:ok, %{status: 400, body: %{"errors" => [%{"message" => "Bad request"}]}}}
             )
  end

  test "handle_error_response extracts error messages from GraphQL format" do
    assert {:error, %Error.ProviderError{details: %{message: "Field is required"}}} =
             Transport.handle_error_response(
               {:ok, %{status: 400, body: %{"errors" => [%{"message" => "Field is required"}]}}}
             )
  end

  test "handle_error_response handles request errors" do
    assert {:error, %Error.ProviderError{provider: :linear}} =
             Transport.handle_error_response({:error, :timeout})
  end

  test "invalid_success_response returns provider error" do
    assert {:error, %Error.ProviderError{provider: :linear, reason: :invalid_response}} =
             Transport.invalid_success_response("test message", %{foo: "bar"})
  end
end
