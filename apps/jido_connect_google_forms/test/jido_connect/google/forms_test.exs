defmodule Jido.Connect.Google.FormsTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Forms
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @readonly_scope "https://www.googleapis.com/auth/forms.body.readonly"
  @write_scope "https://www.googleapis.com/auth/forms.body"

  @forms_action_modules [
    Jido.Connect.Google.Forms.Actions.GetForm
  ]

  @forms_dsl_fragments [
    Jido.Connect.Google.Forms.Actions.Forms
  ]

  test "declares Google Forms provider metadata" do
    spec = Forms.integration()

    assert spec.id == :google_forms
    assert spec.package == :jido_connect_google_forms
    assert spec.name == "Google Forms"
    assert spec.category == :productivity
    assert spec.status == :experimental
    assert spec.tags == [:google, :workspace, :forms, :surveys, :productivity]

    assert Enum.map(spec.actions, & &1.id) == [
             "google.forms.form.get"
           ]

    assert [%{id: :user, kind: :oauth2, refresh?: true, pkce?: true} = profile] =
             spec.auth_profiles

    assert "openid" in profile.default_scopes
    assert "email" in profile.default_scopes
    assert "profile" in profile.default_scopes
    assert @readonly_scope in profile.optional_scopes
    assert @write_scope in profile.optional_scopes

    ConnectorContracts.assert_google_naming_and_catalog_conventions(Forms,
      id_prefix: "google.forms.",
      pack_id_prefix: "google_forms_",
      module_namespace: Jido.Connect.Google.Forms
    )
  end

  test "compiles generated Jido plugin surface" do
    ConnectorContracts.assert_generated_surface(Forms,
      otp_app: :jido_connect_google_forms,
      action_modules: @forms_action_modules,
      plugin_module: Jido.Connect.Google.Forms.Plugin,
      plugin_name: "google_forms"
    )

    ConnectorContracts.assert_catalog_pack_delegates(Forms,
      readonly_pack: :google_forms_readonly,
      editor_pack: :google_forms_editor
    )

    ConnectorContracts.assert_plugin_tool_availability(Forms)
  end

  test "loads Forms Spark DSL fragments" do
    ConnectorContracts.assert_spark_fragments(@forms_dsl_fragments)
  end
end
