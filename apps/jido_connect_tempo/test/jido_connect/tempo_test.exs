defmodule Jido.Connect.TempoTest do
  use ExUnit.Case, async: true

  alias Jido.Connect
  alias Jido.Connect.Tempo

  @labels [
    "tempo.worklogs.read",
    "tempo.worklogs.write",
    "tempo.accounts.read",
    "tempo.periods.read",
    "tempo.approvals.read"
  ]

  test "registers the :tempo provider" do
    spec = Tempo.integration()

    assert spec.id == :tempo
    assert spec.package == :jido_connect_tempo
    assert spec.status == :experimental
    assert spec.actions == []
    assert spec.triggers == []
    assert Application.get_env(:jido_connect_tempo, :jido_connect_providers) == [Tempo]
  end

  test "declares exactly the API token and OAuth user profiles with the five labels" do
    assert [
             %{id: :api_token, kind: :api_key} = api_token,
             %{id: :oauth2_user, kind: :oauth2} = oauth
           ] = Tempo.integration().auth_profiles

    assert api_token.default? == true
    assert api_token.setup == :api_key_bearer_token
    assert api_token.lease_fields == [:api_token]
    assert api_token.scopes == @labels

    assert oauth.default? == false
    assert oauth.authorize_url == "https://api.tempo.io/oauth/authorize/redirect"
    assert oauth.token_url == "https://api.tempo.io/oauth/token/"
    assert oauth.lease_fields == [:access_token]
    assert oauth.credential_fields == [:access_token, :refresh_token]
    assert oauth.refresh? == true
    assert oauth.revoke? == false
    assert oauth.scopes == @labels
  end

  test "compiles a generated plugin surface without actions" do
    assert Tempo.jido_action_modules() == []
    assert Tempo.jido_sensor_modules() == []

    assert %Connect.Catalog.Manifest{
             id: :tempo,
             package: :jido_connect_tempo,
             generated_modules: %{actions: [], sensors: [], plugin: Jido.Connect.Tempo.Plugin}
           } = Tempo.jido_connect_manifest()
  end
end
