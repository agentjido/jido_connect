defmodule Jido.Connect.Google.Docs.Client.TransportTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Error
  alias Jido.Connect.Google.Docs.Client.Transport

  setup do
    docs_url =
      Application.get_env(
        :jido_connect_google_docs,
        :google_docs_api_base_url
      )

    on_exit(fn ->
      restore(:google_docs_api_base_url, docs_url)
    end)
  end

  test "uses configurable Docs API base URL" do
    Application.put_env(
      :jido_connect_google_docs,
      :google_docs_api_base_url,
      "https://docs.example.test"
    )

    assert Transport.docs_base_url() == "https://docs.example.test"
  end

  test "builds Docs v1 bearer requests" do
    Application.put_env(
      :jido_connect_google_docs,
      :google_docs_api_base_url,
      "https://docs.example.test"
    )

    request = Transport.docs_request("token")

    assert request.options.base_url == "https://docs.example.test"
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
             Transport.invalid_success_response("bad Docs response", %{
               "secret" => "long-secret-provider-body"
             })
  end

  defp restore(key, nil), do: Application.delete_env(:jido_connect_google_docs, key)

  defp restore(key, value),
    do: Application.put_env(:jido_connect_google_docs, key, value)
end
