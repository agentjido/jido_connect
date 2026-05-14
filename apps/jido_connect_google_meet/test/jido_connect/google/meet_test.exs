defmodule Jido.Connect.Google.MeetTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Meet
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @meet_readonly_scope "https://www.googleapis.com/auth/meetings.space.readonly"
  @meet_created_scope "https://www.googleapis.com/auth/meetings.space.created"

  test "declares Google Meet provider metadata" do
    spec = Meet.integration()

    assert spec.id == :google_meet
    assert spec.package == :jido_connect_google_meet
    assert spec.name == "Google Meet"
    assert spec.category == :collaboration
    assert spec.status == :experimental
    assert spec.tags == [:google, :workspace, :meetings, :collaboration]
    assert spec.actions == []
    assert spec.triggers == []

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "email" in profile.default_scopes
    assert "profile" in profile.default_scopes
    assert @meet_readonly_scope in profile.optional_scopes
    assert @meet_created_scope in profile.optional_scopes
  end

  test "compiles generated Jido plugin surface" do
    ConnectorContracts.assert_generated_surface(Meet,
      otp_app: :jido_connect_google_meet,
      action_modules: [],
      plugin_module: Jido.Connect.Google.Meet.Plugin,
      plugin_name: "google_meet"
    )
  end
end
