defmodule Jido.Connect.Google.TasksTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Tasks
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @readonly_scope "https://www.googleapis.com/auth/tasks.readonly"
  @write_scope "https://www.googleapis.com/auth/tasks"

  test "declares Google Tasks provider metadata" do
    spec = Tasks.integration()

    assert spec.id == :google_tasks
    assert spec.package == :jido_connect_google_tasks
    assert spec.name == "Google Tasks"
    assert spec.category == :productivity
    assert spec.status == :experimental
    assert spec.tags == [:google, :workspace, :tasks, :productivity]
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
    ConnectorContracts.assert_generated_surface(Tasks,
      otp_app: :jido_connect_google_tasks,
      action_modules: [],
      plugin_module: Jido.Connect.Google.Tasks.Plugin,
      plugin_name: "google_tasks"
    )
  end
end
