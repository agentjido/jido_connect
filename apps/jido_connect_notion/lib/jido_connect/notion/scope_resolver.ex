defmodule Jido.Connect.Notion.ScopeResolver do
  @moduledoc """
  Resolves Notion scopes for action authorization.

  Notion scopes are flat strings (e.g. `read_content`, `read_comments`).
  The resolver maps operation IDs to the minimum required scopes.
  """

  @comment_operations MapSet.new([
                        "notion.comment.list",
                        "notion.comment.create"
                      ])

  @database_operations MapSet.new([
                         "notion.database.get",
                         "notion.database.query"
                       ])

  @content_operations MapSet.new([
                        "notion.search",
                        "notion.page.get",
                        "notion.page.create",
                        "notion.page.update",
                        "notion.block.get",
                        "notion.block.list_children",
                        "notion.block.append_children",
                        "notion.block.update",
                        "notion.block.archive"
                      ])

  @insert_content_operations MapSet.new([
                               "notion.page.create",
                               "notion.block.append_children"
                             ])

  @update_content_operations MapSet.new([
                               "notion.page.update",
                               "notion.block.update",
                               "notion.block.archive"
                             ])

  @insert_comments_operations MapSet.new([
                                "notion.comment.create"
                              ])

  @spec required_scopes(term(), term(), term()) :: [String.t()]
  def required_scopes(operation, _input, _connection) do
    operation
    |> operation_id()
    |> scopes_for_operation()
  end

  defp operation_id(nil), do: nil
  defp operation_id(%{id: id}), do: id
  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(_operation), do: nil

  defp scopes_for_operation(nil), do: ["read_content"]

  defp scopes_for_operation(operation_id) do
    cond do
      MapSet.member?(@insert_comments_operations, operation_id) ->
        ["insert_comments"]

      MapSet.member?(@insert_content_operations, operation_id) ->
        ["insert_content"]

      MapSet.member?(@update_content_operations, operation_id) ->
        ["update_content"]

      MapSet.member?(@comment_operations, operation_id) ->
        ["read_comments"]

      MapSet.member?(@database_operations, operation_id) ->
        ["read_content", "read_databases"]

      MapSet.member?(@content_operations, operation_id) ->
        ["read_content"]

      true ->
        ["read_content"]
    end
  end
end
