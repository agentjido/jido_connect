defmodule Jido.Connect.Notion.Client.Comments do
  @moduledoc "Notion comment read and write API boundary."

  alias Jido.Connect.Notion.Client.{Response, Transport}

  @spec list_comments(map(), String.t()) :: {:ok, map()} | {:error, term()}
  def list_comments(params, access_token) when is_map(params) and is_binary(access_token) do
    query = build_comments_query(params)

    access_token
    |> Transport.request()
    |> Req.get(url: "/comments", params: query)
    |> Response.handle_comment_list_response()
  end

  @spec create_comment(map(), String.t()) :: {:ok, map()} | {:error, term()}
  def create_comment(params, access_token) when is_map(params) and is_binary(access_token) do
    body = build_create_comment_body(params)

    access_token
    |> Transport.request()
    |> Req.post(url: "/comments", json: body)
    |> Response.handle_comment_response()
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

  defp build_create_comment_body(params) do
    body = %{}

    body =
      case Map.get(params, :parent) do
        nil -> body
        parent -> Map.put(body, "parent", parent)
      end

    body =
      case Map.get(params, :discussion_id) do
        nil -> body
        discussion_id -> Map.put(body, "discussion_id", discussion_id)
      end

    body =
      case Map.get(params, :rich_text) do
        nil -> body
        rich_text -> Map.put(body, "rich_text", rich_text)
      end

    body
  end
end
