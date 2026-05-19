defmodule Jido.Connect.Notion.Client.Comments do
  @moduledoc "Notion comment read API boundary."

  alias Jido.Connect.Notion.Client.{Response, Transport}

  @spec list_comments(map(), String.t()) :: {:ok, map()} | {:error, term()}
  def list_comments(params, access_token) when is_map(params) and is_binary(access_token) do
    query = build_comments_query(params)

    access_token
    |> Transport.request()
    |> Req.get(url: "/comments", params: query)
    |> Response.handle_comment_list_response()
  end

  defp build_comments_query(params) do
    query = []

    query =
      case Map.get(params, :block_id) do
        nil -> query
        block_id -> Keyword.put(query, :block_id, block_id)
      end

    query =
      case Map.get(params, :start_cursor) do
        nil -> query
        cursor -> Keyword.put(query, :start_cursor, cursor)
      end

    query =
      case Map.get(params, :page_size) do
        nil -> query
        size -> Keyword.put(query, :page_size, size)
      end

    query
  end
end
