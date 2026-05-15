defmodule Jido.Connect.Google.Tasks.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Tasks.ScopeResolver
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @readonly_scope "https://www.googleapis.com/auth/tasks.readonly"
  @write_scope "https://www.googleapis.com/auth/tasks"

  test "returns readonly scope by default" do
    assert {:module, ScopeResolver} = Code.ensure_loaded(ScopeResolver)

    ConnectorContracts.assert_scope_resolver_shape(ScopeResolver, [@readonly_scope])

    assert ScopeResolver.required_scopes(
             %{id: "google.tasks.tasklist.list"},
             %{},
             %{scopes: [@readonly_scope]}
           ) == [@readonly_scope]

    assert ScopeResolver.required_scopes(
             %{action_id: "google.tasks.task.list"},
             %{},
             %{scopes: []}
           ) == [@readonly_scope]
  end

  test "returns write scope for task list and task mutations" do
    assert ScopeResolver.required_scopes(
             %{id: "google.tasks.tasklist.create"},
             %{},
             %{scopes: [@write_scope]}
           ) == [@write_scope]

    assert ScopeResolver.required_scopes(
             %{id: "google.tasks.task.create"},
             %{},
             %{scopes: [@write_scope]}
           ) == [@write_scope]

    assert ScopeResolver.required_scopes(
             %{id: "google.tasks.task.delete"},
             %{},
             %{scopes: [@write_scope]}
           ) == [@write_scope]

    assert ScopeResolver.required_scopes(
             %{id: "google.tasks.task.move"},
             %{},
             %{scopes: [@write_scope]}
           ) == [@write_scope]
  end

  test "declares Tasks readonly and write scope matrix" do
    ConnectorContracts.assert_scope_matrix(ScopeResolver, [
      %{
        label: "task list defaults to readonly scope",
        operation: "google.tasks.tasklist.list",
        granted: [],
        expected: @readonly_scope
      },
      %{
        label: "task list get requires readonly scope",
        operation: "google.tasks.tasklist.get",
        granted: [@readonly_scope],
        expected: @readonly_scope
      },
      %{
        label: "task list create requires write scope",
        operation: "google.tasks.tasklist.create",
        granted: [],
        expected: @write_scope
      },
      %{
        label: "task list create does not downgrade with readonly grant",
        operation: "google.tasks.tasklist.create",
        granted: [@readonly_scope],
        expected: @write_scope
      },
      %{
        label: "task list create accepts write scope",
        operation: "google.tasks.tasklist.create",
        granted: [@write_scope],
        expected: @write_scope
      },
      %{
        label: "task create requires write scope",
        operation: "google.tasks.task.create",
        granted: [],
        expected: @write_scope
      },
      %{
        label: "task clear requires write scope",
        operation: "google.tasks.task.clear",
        granted: [],
        expected: @write_scope
      },
      %{
        label: "unknown operation defaults to readonly scope",
        operation: "google.tasks.task.unknown_action",
        granted: [],
        expected: @readonly_scope
      }
    ])
  end
end
