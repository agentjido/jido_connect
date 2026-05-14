defmodule Jido.Connect.Google.Analytics.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Analytics.ScopeResolver
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @readonly_scope "https://www.googleapis.com/auth/analytics.readonly"

  test "returns readonly scope by default" do
    assert {:module, ScopeResolver} = Code.ensure_loaded(ScopeResolver)

    ConnectorContracts.assert_scope_resolver_shape(ScopeResolver, [@readonly_scope])

    assert ScopeResolver.required_scopes(
             %{id: "google.analytics.report.run"},
             %{},
             %{scopes: [@readonly_scope]}
           ) == [@readonly_scope]

    assert ScopeResolver.required_scopes(
             %{action_id: "google.analytics.metadata.get"},
             %{},
             %{scopes: []}
           ) == [@readonly_scope]
  end
end
