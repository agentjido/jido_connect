defmodule Jido.Connect.Google.Slides.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Slides.ScopeResolver
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @readonly_scope "https://www.googleapis.com/auth/presentations.readonly"
  @write_scope "https://www.googleapis.com/auth/presentations"

  test "returns readonly scope by default" do
    assert {:module, ScopeResolver} = Code.ensure_loaded(ScopeResolver)

    ConnectorContracts.assert_scope_resolver_shape(ScopeResolver, [@readonly_scope])

    assert ScopeResolver.required_scopes(
             %{id: "google.slides.presentation.get"},
             %{},
             %{scopes: [@readonly_scope]}
           ) == [@readonly_scope]

    assert ScopeResolver.required_scopes(
             %{action_id: "google.slides.presentation.list"},
             %{},
             %{scopes: []}
           ) == [@readonly_scope]
  end

  test "declares Slides readonly scope matrix" do
    ConnectorContracts.assert_scope_matrix(ScopeResolver, [
      %{
        label: "unknown operation defaults to readonly scope",
        operation: "google.slides.presentation.get",
        granted: [],
        expected: @readonly_scope
      },
      %{
        label: "readonly scope is required for read operations",
        operation: "google.slides.presentation.get",
        granted: [@readonly_scope],
        expected: @readonly_scope
      },
      %{
        label: "write scope does not downgrade readonly requirement",
        operation: "google.slides.presentation.get",
        granted: [@write_scope],
        expected: @readonly_scope
      }
    ])
  end
end
