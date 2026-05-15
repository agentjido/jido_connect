defmodule Jido.Connect.Google.Forms.Client.TransportTest do
  use ExUnit.Case, async: false

  alias Jido.Connect.Google.Forms.Client.Transport

  test "returns default base URL" do
    assert Transport.forms_base_url() == "https://forms.googleapis.com"
  end

  test "returns configured base URL" do
    Application.put_env(
      :jido_connect_google_forms,
      :google_forms_api_base_url,
      "https://forms.test"
    )

    assert Transport.forms_base_url() == "https://forms.test"

    Application.delete_env(:jido_connect_google_forms, :google_forms_api_base_url)
  end

  test "builds bearer request" do
    req = Transport.forms_request("token123")

    assert req.headers["authorization"] == ["Bearer token123"]
    assert req.headers["accept"] == ["application/json"]
  end
end
