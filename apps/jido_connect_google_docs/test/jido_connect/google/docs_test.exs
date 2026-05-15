defmodule Jido.Connect.Google.DocsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Docs
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @readonly_scope "https://www.googleapis.com/auth/documents.readonly"
  @write_scope "https://www.googleapis.com/auth/documents"

  test "declares Google Docs provider metadata" do
    spec = Docs.integration()

    assert spec.id == :google_docs
    assert spec.package == :jido_connect_google_docs
    assert spec.name == "Google Docs"
    assert spec.category == :productivity
    assert spec.status == :experimental
    assert spec.tags == [:google, :workspace, :docs, :documents, :productivity]
    assert spec.actions == []
    assert spec.triggers == []

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "email" in profile.default_scopes
    assert "profile" in profile.default_scopes
    assert @readonly_scope in profile.optional_scopes
    assert @write_scope in profile.optional_scopes
  end

  test "compiles generated Jido plugin surface" do
    ConnectorContracts.assert_generated_surface(Docs,
      otp_app: :jido_connect_google_docs,
      action_modules: [],
      plugin_module: Jido.Connect.Google.Docs.Plugin,
      plugin_name: "google_docs"
    )
  end
end
