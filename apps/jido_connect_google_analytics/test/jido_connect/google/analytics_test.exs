defmodule Jido.Connect.Google.AnalyticsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Analytics
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @analytics_readonly_scope "https://www.googleapis.com/auth/analytics.readonly"

  test "declares Google Analytics provider metadata" do
    spec = Analytics.integration()

    assert spec.id == :google_analytics
    assert spec.package == :jido_connect_google_analytics
    assert spec.name == "Google Analytics"
    assert spec.category == :marketing
    assert spec.status == :experimental
    assert spec.tags == [:google, :workspace, :analytics, :reporting]
    assert spec.actions == []
    assert spec.triggers == []

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "email" in profile.default_scopes
    assert "profile" in profile.default_scopes
    assert @analytics_readonly_scope in profile.optional_scopes
  end

  test "compiles generated Jido plugin surface" do
    ConnectorContracts.assert_generated_surface(Analytics,
      otp_app: :jido_connect_google_analytics,
      action_modules: [],
      plugin_module: Jido.Connect.Google.Analytics.Plugin,
      plugin_name: "google_analytics"
    )
  end
end
