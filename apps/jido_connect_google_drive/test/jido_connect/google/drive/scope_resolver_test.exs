defmodule Jido.Connect.Google.Drive.ScopeResolverTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Drive.ScopeResolver
  alias Jido.Connect.Google.TestSupport.ConnectorContracts

  @metadata_scope "https://www.googleapis.com/auth/drive.metadata.readonly"
  @file_scope "https://www.googleapis.com/auth/drive.file"
  @readonly_scope "https://www.googleapis.com/auth/drive.readonly"

  test "declares Drive metadata, content, broad, and mutation scope matrix" do
    ConnectorContracts.assert_scope_matrix(ScopeResolver, [
      %{
        label: "missing product grant falls back to metadata read scope",
        operation: "google.drive.file.get",
        granted: [],
        expected: @metadata_scope
      },
      %{
        label: "narrow metadata scope remains least-privilege",
        operation: "google.drive.files.list",
        granted: [@metadata_scope],
        expected: @metadata_scope
      },
      %{
        label: "broad readonly grant can satisfy metadata reads",
        operation: "google.drive.permissions.list",
        granted: [@readonly_scope],
        expected: @readonly_scope
      },
      %{
        label: "revision reads default to metadata read scope",
        operation: "google.drive.revisions.list",
        granted: [],
        expected: @metadata_scope
      },
      %{
        label: "permission get accepts drive.file for app-owned files",
        operation: "google.drive.permission.get",
        granted: [@file_scope],
        expected: @file_scope
      },
      %{
        label: "drive.file grant can satisfy metadata reads for app-owned files",
        operation: "google.drive.file.get",
        granted: [@file_scope],
        expected: @file_scope
      },
      %{
        label: "content read prefers drive.readonly when no broader grant exists",
        operation: "google.drive.file.download",
        granted: [],
        expected: @readonly_scope
      },
      %{
        label: "content read accepts drive.file for app-owned files",
        operation: "google.drive.file.export",
        granted: [@file_scope],
        expected: @file_scope
      },
      %{
        label: "file mutation requires drive.file scope",
        operation: "google.drive.file.update",
        granted: [@readonly_scope],
        expected: @file_scope
      },
      %{
        label: "permission mutation requires drive.file scope",
        operation: "google.drive.permission.update",
        granted: [],
        expected: @file_scope
      },
      %{
        label: "revision mutation requires drive.file scope",
        operation: "google.drive.revision.delete",
        granted: [],
        expected: @file_scope
      },
      %{
        label: "changes watch defaults to metadata read scope",
        operation: "google.drive.changes.watch",
        granted: [],
        expected: @metadata_scope
      },
      %{
        label: "file watch accepts drive.file for app-owned files",
        operation: "google.drive.file.watch",
        granted: [@file_scope],
        expected: @file_scope
      },
      %{
        label: "channel stop accepts broad readonly grant",
        operation: "google.drive.channel.stop",
        granted: [@readonly_scope],
        expected: @readonly_scope
      }
    ])
  end
end
