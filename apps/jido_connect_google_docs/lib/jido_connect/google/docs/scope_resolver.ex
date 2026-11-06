defmodule Jido.Connect.Google.Docs.ScopeResolver do
  @moduledoc """
  Resolves Google Docs scopes.

  Google Docs exposes both read-only and read-write operations. Write
  operations always require `documents`.

  Read operations require the first of these scopes that the connection
  holds, and `documents.readonly` when it holds none of them:

  1. `documents.readonly`
  2. `documents`
  3. `drive`

  Google accepts each of them for a Docs read. On 2026-11-06 it returned a
  multi-tab document to an access token that held only `drive`. Neither
  `drive.readonly` nor `drive.file` satisfies a read here: neither was
  checked live, and finer Drive grants are left to the host. `drive` never
  satisfies a write.

  The resolver stays package-local so later action families can preserve
  least-privilege behavior without adding generic Docs scope logic to
  `jido_connect` core.
  """

  @readonly_scope "https://www.googleapis.com/auth/documents.readonly"
  @write_scope "https://www.googleapis.com/auth/documents"
  @drive_scope "https://www.googleapis.com/auth/drive"

  @read_scopes [@readonly_scope, @write_scope, @drive_scope]

  @write_operations MapSet.new([
                      "google.docs.document.create",
                      "google.docs.document.batch_update"
                    ])

  def required_scopes(operation, _input, connection) do
    if MapSet.member?(@write_operations, operation_id(operation)) do
      [@write_scope]
    else
      read_scopes(connection)
    end
  end

  defp read_scopes(%{scopes: scopes}) when is_list(scopes) do
    [Enum.find(@read_scopes, @readonly_scope, &(&1 in scopes))]
  end

  defp read_scopes(_connection), do: [@readonly_scope]

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(_operation), do: nil
end
