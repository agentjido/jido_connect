defmodule Jido.Connect.Google.Analytics.Client.TransportTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.Google.Analytics.Client.Transport

  setup do
    data_url =
      Application.get_env(:jido_connect_google_analytics, :google_analytics_data_api_base_url)

    admin_url =
      Application.get_env(:jido_connect_google_analytics, :google_analytics_admin_api_base_url)

    on_exit(fn ->
      restore(:google_analytics_data_api_base_url, data_url)
      restore(:google_analytics_admin_api_base_url, admin_url)
    end)
  end

  test "uses configurable Analytics API base URLs" do
    Application.put_env(
      :jido_connect_google_analytics,
      :google_analytics_data_api_base_url,
      "https://analytics-data.example.test"
    )

    Application.put_env(
      :jido_connect_google_analytics,
      :google_analytics_admin_api_base_url,
      "https://analytics-admin.example.test"
    )

    assert Transport.data_base_url() == "https://analytics-data.example.test"
    assert Transport.admin_base_url() == "https://analytics-admin.example.test"
  end

  test "builds Analytics Data API bearer requests" do
    Application.put_env(
      :jido_connect_google_analytics,
      :google_analytics_data_api_base_url,
      "https://analytics-data.example.test"
    )

    request = Transport.data_request("token")

    assert request.options.base_url == "https://analytics-data.example.test"
    assert request.headers["authorization"] == ["Bearer token"]
    assert request.headers["accept"] == ["application/json"]
  end

  test "builds Analytics Admin API bearer requests" do
    Application.put_env(
      :jido_connect_google_analytics,
      :google_analytics_admin_api_base_url,
      "https://analytics-admin.example.test"
    )

    request = Transport.admin_request("token")

    assert request.options.base_url == "https://analytics-admin.example.test"
    assert request.headers["authorization"] == ["Bearer token"]
    assert request.headers["accept"] == ["application/json"]
  end

  test "delegates Google error normalization" do
    assert {:error,
            %Error.ProviderError{
              provider: :google,
              reason: :http_error,
              status: 403,
              details: %{message: "denied"}
            }} =
             Transport.handle_error_response(
               {:ok, %{status: 403, body: %{"error" => %{"message" => "denied"}}}}
             )
  end

  test "delegates malformed success normalization" do
    assert {:error,
            %Error.ProviderError{
              provider: :google,
              reason: :invalid_response,
              details: %{body_summary: %{type: :map, keys: ["secret"]}}
            }} =
             Transport.invalid_success_response("bad Analytics response", %{
               "secret" => "long-secret-provider-body"
             })
  end

  defp restore(key, nil), do: Application.delete_env(:jido_connect_google_analytics, key)
  defp restore(key, value), do: Application.put_env(:jido_connect_google_analytics, key, value)
end
