defmodule Jido.Connect.Google.SearchConsole.ScopeResolver do
  @moduledoc """
  Resolves Google Search Console scopes.

  Search Console exposes both read-only reporting operations and write
  operations for site and sitemap management. The resolver stays package-local
  so later action families can preserve least-privilege behavior without adding
  generic Search Console scope logic to `jido_connect` core.
  """

  @readonly_scope "https://www.googleapis.com/auth/webmasters.readonly"
  @write_scope "https://www.googleapis.com/auth/webmasters"

  @write_operations MapSet.new([
                      "google.search_console.site.add",
                      "google.search_console.site.delete",
                      "google.search_console.sitemap.delete",
                      "google.search_console.sitemap.submit"
                    ])

  def required_scopes(operation, _input, _connection) do
    operation
    |> operation_id()
    |> required_for_operation()
  end

  defp required_for_operation(operation_id) do
    if MapSet.member?(@write_operations, operation_id) do
      [@write_scope]
    else
      [@readonly_scope]
    end
  end

  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(_operation), do: nil
end
