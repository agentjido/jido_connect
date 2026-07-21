defmodule Jido.Connect.Nextcloud.Client.CredentialsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Nextcloud.Client.Credentials

  test "extracts app-password credentials" do
    assert {:ok, credentials} =
             Credentials.from_credentials(%{
               base_url: "https://cloud.example.com/",
               login_name: "alice",
               app_password: "secret"
             })

    assert credentials.base_url == "https://cloud.example.com"
    assert credentials.login_name == "alice"
    assert {"authorization", "Basic " <> _} = Credentials.authorization_header(credentials)
  end

  test "extracts bearer credentials" do
    assert {:ok, credentials} =
             Credentials.from_credentials(%{
               "base_url" => "https://cloud.example.com",
               "access_token" => "token"
             })

    assert Credentials.authorization_header(credentials) == {"authorization", "Bearer token"}
  end

  test "returns auth errors for missing required credentials" do
    assert {:error, %Jido.Connect.Error.AuthError{reason: :missing_base_url}} =
             Credentials.from_credentials(%{})

    assert {:error, %Jido.Connect.Error.AuthError{reason: :missing_credentials}} =
             Credentials.from_credentials(%{base_url: "https://cloud.example.com"})
  end
end
