defmodule Jido.Connect.Google.Analytics.Client.ResponseTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Error
  alias Jido.Connect.Google.Analytics.Client.Response

  test "rejects non-map metadata success payloads" do
    assert {:error, %Error.ProviderError{reason: :invalid_response}} =
             Response.handle_metadata_response({:ok, %{status: 200, body: "bad"}})
  end

  test "normalizes provider error responses" do
    assert {:error,
            %Error.ProviderError{
              provider: :google,
              reason: :http_error,
              status: 403,
              details: %{message: "denied"}
            }} =
             Response.handle_metadata_response(
               {:ok, %{status: 403, body: %{"error" => %{"message" => "denied"}}}}
             )
  end
end
