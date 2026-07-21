defmodule Jido.Connect.Calendly.Client.TransportTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Calendly.Client.Transport
  alias Jido.Connect.Error

  setup do
    on_exit(fn ->
      Application.delete_env(:jido_connect_calendly, :calendly_api_base_url)
      Application.delete_env(:jido_connect_calendly, :calendly_req_options)
    end)
  end

  test "builds bearer requests with default base URL" do
    Application.delete_env(:jido_connect_calendly, :calendly_api_base_url)

    request = Transport.api_request("cal_test_key")

    assert Transport.base_url() == "https://api.calendly.com"
    assert request.options.base_url == "https://api.calendly.com"
    assert request.headers["authorization"] == ["Bearer cal_test_key"]
    assert request.headers["accept"] == ["application/json"]
  end

  test "builds bearer requests with configurable base URL" do
    Application.put_env(:jido_connect_calendly, :calendly_api_base_url, "https://calendly.test")

    request = Transport.api_request("cal_test_key")

    assert Transport.base_url() == "https://calendly.test"
    assert request.options.base_url == "https://calendly.test"
  end

  test "handles Calendly error response shapes" do
    assert {:error,
            %Error.ProviderError{
              provider: :calendly,
              reason: :http_error,
              status: 401,
              details: %{message: "Unauthorized"}
            }} =
             Transport.handle_error_response(
               {:ok, %{status: 401, body: %{"message" => "Unauthorized"}}}
             )

    assert {:error,
            %Error.ProviderError{
              provider: :calendly,
              reason: :http_error,
              status: 403,
              details: %{message: "Forbidden"}
            }} =
             Transport.handle_error_response(
               {:ok, %{status: 403, body: %{"error" => "Forbidden"}}}
             )
  end

  test "handles generic error responses" do
    assert {:error, %Error.ProviderError{provider: :calendly}} =
             Transport.handle_error_response({:error, %RuntimeError{message: "network down"}})
  end

  test "returns invalid success response error" do
    assert {:error, %Error.ProviderError{provider: :calendly, reason: :invalid_response}} =
             Transport.invalid_success_response("bad payload", %{})
  end
end
