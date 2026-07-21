defmodule Jido.Connect.Notion.Client do
  @moduledoc """
  Notion API client facade.

  Delegates to capability-oriented client modules for search, pages,
  databases, blocks, and comments.
  """

  defdelegate search(params, access_token), to: __MODULE__.Search
  defdelegate get_page(page_id, access_token), to: __MODULE__.Pages
  defdelegate create_page(params, access_token), to: __MODULE__.Pages
  defdelegate update_page(page_id, params, access_token), to: __MODULE__.Pages
  defdelegate get_database(database_id, access_token), to: __MODULE__.Databases
  defdelegate query_database(database_id, params, access_token), to: __MODULE__.Databases
  defdelegate retrieve_block(block_id, access_token), to: __MODULE__.Blocks

  defdelegate list_block_children(block_id, params, access_token), to: __MODULE__.Blocks
  defdelegate append_block_children(block_id, params, access_token), to: __MODULE__.Blocks
  defdelegate update_block(block_id, params, access_token), to: __MODULE__.Blocks
  defdelegate archive_block(block_id, access_token), to: __MODULE__.Blocks
  defdelegate list_comments(params, access_token), to: __MODULE__.Comments
  defdelegate create_comment(params, access_token), to: __MODULE__.Comments
end
