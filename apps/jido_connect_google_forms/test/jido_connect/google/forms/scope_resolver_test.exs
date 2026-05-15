defmodule Jido.Connect.Google.Forms.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Forms.ScopeResolver
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @readonly_scope "https://www.googleapis.com/auth/forms.body.readonly"
  @write_scope "https://www.googleapis.com/auth/forms.body"
  @responses_readonly_scope "https://www.googleapis.com/auth/forms.responses.readonly"

  test "returns readonly scope by default" do
    assert {:module, ScopeResolver} = Code.ensure_loaded(ScopeResolver)

    ConnectorContracts.assert_scope_resolver_shape(ScopeResolver, [@readonly_scope])

    assert ScopeResolver.required_scopes(
             %{id: "google.forms.form.get"},
             %{},
             %{scopes: [@readonly_scope]}
           ) == [@readonly_scope]

    assert ScopeResolver.required_scopes(
             %{action_id: "google.forms.form.list"},
             %{},
             %{scopes: []}
           ) == [@readonly_scope]
  end

  test "returns write scope for create and batch update operations" do
    assert ScopeResolver.required_scopes(
             %{id: "google.forms.form.create"},
             %{},
             %{scopes: [@write_scope]}
           ) == [@write_scope]

    assert ScopeResolver.required_scopes(
             %{id: "google.forms.form.batch_update"},
             %{},
             %{scopes: [@write_scope]}
           ) == [@write_scope]
  end

  test "declares Forms readonly and write scope matrix" do
    ConnectorContracts.assert_scope_matrix(ScopeResolver, [
      %{
        label: "get form defaults to readonly scope",
        operation: "google.forms.form.get",
        granted: [],
        expected: @readonly_scope
      },
      %{
        label: "get form requires readonly scope",
        operation: "google.forms.form.get",
        granted: [@readonly_scope],
        expected: @readonly_scope
      },
      %{
        label: "create form requires write scope",
        operation: "google.forms.form.create",
        granted: [],
        expected: @write_scope
      },
      %{
        label: "create form does not downgrade with readonly grant",
        operation: "google.forms.form.create",
        granted: [@readonly_scope],
        expected: @write_scope
      },
      %{
        label: "create form accepts write scope",
        operation: "google.forms.form.create",
        granted: [@write_scope],
        expected: @write_scope
      },
      %{
        label: "batch update requires write scope",
        operation: "google.forms.form.batch_update",
        granted: [],
        expected: @write_scope
      },
      %{
        label: "batch update accepts write scope",
        operation: "google.forms.form.batch_update",
        granted: [@write_scope],
        expected: @write_scope
      },
      %{
        label: "list responses requires responses readonly scope",
        operation: "google.forms.responses.list",
        granted: [],
        expected: @responses_readonly_scope
      },
      %{
        label: "get response requires responses readonly scope",
        operation: "google.forms.responses.get",
        granted: [],
        expected: @responses_readonly_scope
      },
      %{
        label: "list responses does not accept body readonly scope",
        operation: "google.forms.responses.list",
        granted: [@readonly_scope],
        expected: @responses_readonly_scope
      },
      %{
        label: "unknown operation defaults to readonly scope",
        operation: "google.forms.form.unknown_action",
        granted: [],
        expected: @readonly_scope
      },
      %{
        label: "create watch requires responses readonly scope",
        operation: "google.forms.watch.create",
        granted: [],
        expected: @responses_readonly_scope
      },
      %{
        label: "renew watch requires responses readonly scope",
        operation: "google.forms.watch.renew",
        granted: [],
        expected: @responses_readonly_scope
      },
      %{
        label: "delete watch requires responses readonly scope",
        operation: "google.forms.watch.delete",
        granted: [],
        expected: @responses_readonly_scope
      },
      %{
        label: "create watch does not accept body readonly scope",
        operation: "google.forms.watch.create",
        granted: [@readonly_scope],
        expected: @responses_readonly_scope
      }
    ])
  end
end
