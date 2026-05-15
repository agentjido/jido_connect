defmodule Jido.Connect.Google.Docs.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Docs.ScopeResolver
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @readonly_scope "https://www.googleapis.com/auth/documents.readonly"
  @write_scope "https://www.googleapis.com/auth/documents"

  test "returns readonly scope by default" do
    assert {:module, ScopeResolver} = Code.ensure_loaded(ScopeResolver)

    ConnectorContracts.assert_scope_resolver_shape(ScopeResolver, [@readonly_scope])

    assert ScopeResolver.required_scopes(
             %{id: "google.docs.document.get"},
             %{},
             %{scopes: [@readonly_scope]}
           ) == [@readonly_scope]

    assert ScopeResolver.required_scopes(
             %{action_id: "google.docs.document.list"},
             %{},
             %{scopes: []}
           ) == [@readonly_scope]
  end

  test "returns write scope for future create and batch update operations" do
    assert ScopeResolver.required_scopes(
             %{id: "google.docs.document.create"},
             %{},
             %{scopes: [@write_scope]}
           ) == [@write_scope]

    assert ScopeResolver.required_scopes(
             %{id: "google.docs.document.batch_update"},
             %{},
             %{scopes: [@write_scope]}
           ) == [@write_scope]
  end
end
