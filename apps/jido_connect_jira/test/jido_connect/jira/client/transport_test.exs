defmodule Jido.Connect.Jira.Client.TransportTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error
  alias Jido.Connect.Jira.Client.Transport

  test "base_url returns default Jira API base URL" do
    assert Transport.base_url() == "https://your-domain.atlassian.net"
  end

  test "request builds a bearer request" do
    request = Transport.request("test-token")

    assert %Req.Request{} = request
    assert request.options.base_url == "https://your-domain.atlassian.net"
    assert request.headers["authorization"] == ["Bearer test-token"]
    assert request.headers["accept"] == ["application/json"]
  end

  test "request accepts custom base URL via opts" do
    request = Transport.request("test-token", base_url: "https://custom.atlassian.net")
    assert request.options.base_url == "https://custom.atlassian.net"
  end

  test "request uses configured application env base URL" do
    original = Application.get_env(:jido_connect_jira, :jira_api_base_url)

    try do
      Application.put_env(:jido_connect_jira, :jira_api_base_url, "https://env.atlassian.net")
      assert Transport.base_url() == "https://env.atlassian.net"

      request = Transport.request("test-token")
      assert request.options.base_url == "https://env.atlassian.net"
    after
      if original do
        Application.put_env(:jido_connect_jira, :jira_api_base_url, original)
      else
        Application.delete_env(:jido_connect_jira, :jira_api_base_url)
      end
    end
  end

  test "handle_error_response normalizes HTTP error bodies" do
    assert {:error, %Error.ProviderError{provider: :jira, reason: :http_error, status: 400}} =
             Transport.handle_error_response(
               {:ok, %{status: 400, body: %{"errorMessages" => ["Bad request"]}}}
             )
  end

  test "handle_error_response extracts error messages from Jira format" do
    assert {:error, %Error.ProviderError{details: %{message: "Field is required"}}} =
             Transport.handle_error_response(
               {:ok, %{status: 400, body: %{"errorMessages" => ["Field is required"]}}}
             )
  end

  test "handle_error_response handles request errors" do
    assert {:error, %Error.ProviderError{provider: :jira}} =
             Transport.handle_error_response({:error, :timeout})
  end

  test "invalid_success_response returns provider error" do
    assert {:error, %Error.ProviderError{provider: :jira, reason: :invalid_response}} =
             Transport.invalid_success_response("test message", %{foo: "bar"})
  end
end
