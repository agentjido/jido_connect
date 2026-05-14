defmodule Jido.Connect.Google.Meet.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Meet.ScopeResolver
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @created_scope "https://www.googleapis.com/auth/meetings.space.created"
  @readonly_scope "https://www.googleapis.com/auth/meetings.space.readonly"
  @settings_scope "https://www.googleapis.com/auth/meetings.space.settings"

  test "resolves Meet scopes for scaffolded operation shapes" do
    assert {:module, ScopeResolver} = Code.ensure_loaded(ScopeResolver)

    ConnectorContracts.assert_scope_resolver_shape(ScopeResolver, @readonly_scope)

    assert ScopeResolver.required_scopes(
             %{id: "google.meet.space.create"},
             %{},
             %{scopes: [@created_scope]}
           ) == [@created_scope]

    assert ScopeResolver.required_scopes(
             %{action_id: "google.meet.space.get"},
             %{},
             %{scopes: [@readonly_scope]}
           ) == [@readonly_scope]

    assert ScopeResolver.required_scopes(
             %{action_id: "google.meet.space.get"},
             %{},
             %{scopes: [@created_scope]}
           ) == [@created_scope]

    assert ScopeResolver.required_scopes(
             %{action_id: "google.meet.space.get"},
             %{},
             %{scopes: [@settings_scope]}
           ) == [@settings_scope]

    assert ScopeResolver.required_scopes(
             %{action_id: "google.meet.conference_record.list"},
             %{},
             %{scopes: [@readonly_scope]}
           ) == [@readonly_scope]

    assert ScopeResolver.required_scopes(
             %{action_id: "google.meet.conference_record.get"},
             %{},
             %{scopes: [@created_scope]}
           ) == [@created_scope]
  end
end
