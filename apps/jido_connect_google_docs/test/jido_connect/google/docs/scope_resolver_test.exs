defmodule Jido.Connect.Google.Docs.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Docs.ScopeResolver
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @readonly_scope "https://www.googleapis.com/auth/documents.readonly"
  @write_scope "https://www.googleapis.com/auth/documents"
  @drive_scope "https://www.googleapis.com/auth/drive"
  @drive_readonly_scope "https://www.googleapis.com/auth/drive.readonly"
  @drive_file_scope "https://www.googleapis.com/auth/drive.file"

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

  test "declares Docs readonly and write scope matrix" do
    ConnectorContracts.assert_scope_matrix(ScopeResolver, [
      %{
        label: "get document defaults to readonly scope",
        operation: "google.docs.document.get",
        granted: [],
        expected: @readonly_scope
      },
      %{
        label: "get document requires readonly scope",
        operation: "google.docs.document.get",
        granted: [@readonly_scope],
        expected: @readonly_scope
      },
      %{
        label: "get document accepts an existing write grant",
        operation: "google.docs.document.get",
        granted: [@write_scope],
        expected: @write_scope
      },
      %{
        label: "get document prefers readonly scope when both are granted",
        operation: "google.docs.document.get",
        granted: [@write_scope, @readonly_scope],
        expected: @readonly_scope
      },
      %{
        label: "create document requires write scope",
        operation: "google.docs.document.create",
        granted: [],
        expected: @write_scope
      },
      %{
        label: "create document does not downgrade with readonly grant",
        operation: "google.docs.document.create",
        granted: [@readonly_scope],
        expected: @write_scope
      },
      %{
        label: "create document accepts write scope",
        operation: "google.docs.document.create",
        granted: [@write_scope],
        expected: @write_scope
      },
      %{
        label: "batch update requires write scope",
        operation: "google.docs.document.batch_update",
        granted: [],
        expected: @write_scope
      },
      %{
        label: "batch update accepts write scope",
        operation: "google.docs.document.batch_update",
        granted: [@write_scope],
        expected: @write_scope
      },
      %{
        label: "unknown operation defaults to readonly scope",
        operation: "google.docs.document.unknown_action",
        granted: [],
        expected: @readonly_scope
      }
    ])
  end

  # Google accepted a Docs read with an access token narrowed to `drive` on
  # 2026-11-06. `drive.readonly` and `drive.file` were not checked live, so
  # they satisfy no read.
  test "declares the Drive grant matrix for reads and writes" do
    ConnectorContracts.assert_scope_matrix(ScopeResolver, [
      %{
        label: "get document accepts a drive grant",
        operation: "google.docs.document.get",
        granted: [@drive_scope],
        expected: @drive_scope
      },
      %{
        label: "get document prefers the write scope over a drive grant",
        operation: "google.docs.document.get",
        granted: [@drive_scope, @write_scope],
        expected: @write_scope
      },
      %{
        label: "get document prefers readonly scope over a drive grant",
        operation: "google.docs.document.get",
        granted: [@drive_scope, @readonly_scope],
        expected: @readonly_scope
      },
      %{
        label: "get document does not accept drive.readonly",
        operation: "google.docs.document.get",
        granted: [@drive_readonly_scope],
        expected: @readonly_scope
      },
      %{
        label: "get document does not accept drive.file",
        operation: "google.docs.document.get",
        granted: [@drive_file_scope],
        expected: @readonly_scope
      },
      %{
        label: "create document does not accept a drive grant",
        operation: "google.docs.document.create",
        granted: [@drive_scope],
        expected: @write_scope
      },
      %{
        label: "batch update does not accept a drive grant",
        operation: "google.docs.document.batch_update",
        granted: [@drive_scope],
        expected: @write_scope
      }
    ])
  end
end
