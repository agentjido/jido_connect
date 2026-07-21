defmodule Jido.Connect.Google.SlidesTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Slides
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @readonly_scope "https://www.googleapis.com/auth/presentations.readonly"
  @write_scope "https://www.googleapis.com/auth/presentations"

  test "declares Google Slides provider metadata" do
    spec = Slides.integration()

    assert spec.id == :google_slides
    assert spec.package == :jido_connect_google_slides
    assert spec.name == "Google Slides"
    assert spec.category == :productivity
    assert spec.status == :experimental
    assert spec.tags == [:google, :workspace, :slides, :presentations, :productivity]

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "email" in profile.default_scopes
    assert "profile" in profile.default_scopes
    assert @readonly_scope in profile.optional_scopes
    assert @write_scope in profile.optional_scopes

    ConnectorContracts.assert_google_naming_and_catalog_conventions(Slides,
      id_prefix: "google.slides.",
      pack_id_prefix: "google_slides_",
      module_namespace: Jido.Connect.Google.Slides
    )
  end

  test "compiles generated Jido plugin surface" do
    ConnectorContracts.assert_generated_surface(Slides,
      otp_app: :jido_connect_google_slides,
      action_modules: [
        Jido.Connect.Google.Slides.Actions.GetPresentation,
        Jido.Connect.Google.Slides.Actions.CreatePresentation,
        Jido.Connect.Google.Slides.Actions.BatchUpdate,
        Jido.Connect.Google.Slides.Actions.GetPageThumbnail
      ],
      plugin_module: Jido.Connect.Google.Slides.Plugin,
      plugin_name: "google_slides"
    )

    ConnectorContracts.assert_catalog_pack_delegates(Slides,
      readonly_pack: :google_slides_readonly,
      editor_pack: :google_slides_editor
    )

    ConnectorContracts.assert_plugin_tool_availability(Slides)
  end

  test "loads Slides Spark DSL fragments" do
    ConnectorContracts.assert_spark_fragments([
      Jido.Connect.Google.Slides.Actions.Presentations
    ])
  end
end
