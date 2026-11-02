defmodule Jido.Connect.Google.Docs.ScopeResolver do
  @moduledoc """
  Resolves Google Docs scopes.

  Google Docs exposes both read-only and read-write operations. Write
  operations always require `documents`. Read operations require
  `documents.readonly`, unless the connection already holds `documents`
  without `documents.readonly`; Google accepts that broader grant for reads.

  The resolver stays package-local so later action families can preserve
  least-privilege behavior without adding generic Docs scope logic to
  `jido_connect` core.
  """

  @readonly_scope "https://www.googleapis.com/auth/documents.readonly"
  @write_scope "https://www.googleapis.com/auth/documents"

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
    if @write_scope in scopes and @readonly_scope not in scopes do
      [@write_scope]
    else
      [@readonly_scope]
    end
  end

  defp read_scopes(_connection), do: [@readonly_scope]

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(_operation), do: nil
end
