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

  test "normalizes error responses" do
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

  test "normalizes alternate error response shapes and request failures" do
    assert {:error, %Error.ProviderError{details: %{message: "atom denied"}}} =
             Transport.handle_error_response(
               {:ok, %{status: 403, body: %{error: %{message: "atom denied"}}}}
             )

    assert {:error, %Error.ProviderError{details: %{message: "plain denied"}}} =
             Transport.handle_error_response(
               {:ok, %{status: 403, body: %{"error" => "plain denied"}}}
             )

    assert {:error, %Error.ProviderError{details: %{message: "atom plain denied"}}} =
             Transport.handle_error_response(
               {:ok, %{status: 403, body: %{error: "atom plain denied"}}}
             )

    assert {:error,
            %Error.ProviderError{
              provider: :microsoft,
              reason: :request_error,
              details: %{reason: :timeout}
            }} =
             Transport.handle_error_response({:error, :timeout}, message: "Microsoft timeout")
  end
end
