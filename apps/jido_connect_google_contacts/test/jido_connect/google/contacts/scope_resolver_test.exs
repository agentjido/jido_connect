defmodule Jido.Connect.Google.Contacts.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Contacts.ScopeResolver
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @contacts_scope "https://www.googleapis.com/auth/contacts"
  @contacts_readonly_scope "https://www.googleapis.com/auth/contacts.readonly"
  @contacts_other_readonly_scope "https://www.googleapis.com/auth/contacts.other.readonly"
  @directory_readonly_scope "https://www.googleapis.com/auth/directory.readonly"
  @profile_scope "profile"

  test "declares Contacts read and mutation scope matrix" do
    assert {:module, ScopeResolver} = Code.ensure_loaded(ScopeResolver)

    ConnectorContracts.assert_scope_resolver_shape(ScopeResolver, @contacts_readonly_scope)

    ConnectorContracts.assert_scope_matrix(ScopeResolver, [
      %{
        label: "missing contact read grant falls back to readonly Contacts scope",
        operation: "google.contacts.person.list",
        granted: [],
        expected: @contacts_readonly_scope
      },
      %{
        label: "contact search uses readonly Contacts scope",
        operation: "google.contacts.person.search",
        granted: [@contacts_readonly_scope],
        expected: @contacts_readonly_scope
      },
      %{
        label: "contact mutation requires Contacts write scope",
        operation: "google.contacts.person.update",
        granted: [@contacts_readonly_scope],
        expected: @contacts_scope
      },
      %{
        label: "batch contact mutation requires Contacts write scope",
        operation: "google.contacts.person.batch_update",
        granted: [@contacts_readonly_scope],
        expected: @contacts_scope
      },
      %{
        label: "directory listing requires directory readonly scope",
        operation: "google.contacts.directory.list",
        granted: [@contacts_readonly_scope],
        expected: @directory_readonly_scope
      },
      %{
        label: "other contacts read requires other contacts readonly scope",
        operation: "google.contacts.other.list",
        granted: [@contacts_scope],
        expected: @contacts_other_readonly_scope
      },
      %{
        label: "copying other contacts accepts Contacts write scope",
        operation: "google.contacts.other.copy",
        granted: [@contacts_scope],
        expected: @contacts_scope
      },
      %{
        label: "group mutation requires Contacts write scope",
        operation: "google.contacts.group.member.modify",
        granted: [@contacts_readonly_scope],
        expected: @contacts_scope
      },
      %{
        label: "group batch get uses Contacts readonly scope",
        operation: "google.contacts.group.batch_get",
        granted: [],
        expected: @contacts_readonly_scope
      }
    ])

    assert ScopeResolver.required_scopes(
             %{id: "google.contacts.person.get"},
             %{resource_name: "people/me"},
             %{scopes: [@profile_scope]}
           ) == [@profile_scope]

    assert ScopeResolver.required_scopes(
             %{id: "google.contacts.person.get"},
             %{resource_name: "people/c123"},
             %{scopes: []}
           ) == [@contacts_readonly_scope]

    assert ScopeResolver.required_scopes(
             %{id: "google.contacts.person.get"},
             %{resource_name: "people/me"},
             %{scopes: [@contacts_scope]}
           ) == [@contacts_scope]
  end
end
