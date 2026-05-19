defmodule Jido.Connect.Notion.Client.Blocks do
  @moduledoc "Notion block read API boundary."

  alias Jido.Connect.Notion.Client.{Response, Transport}

  @spec retrieve_block(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def retrieve_block(block_id, access_token)
      when is_binary(block_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/blocks/#{URI.encode(block_id, &URI.char_unreserved?/1)}")
    |> Response.handle_block_response()
  end

  @spec list_block_children(String.t(), map(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def list_block_children(block_id, params, access_token)
      when is_binary(block_id) and is_map(params) and is_binary(access_token) do
    query = build_children_query(params)

    access_token
    |> Transport.request()
    |> Req.get(
      url: "/blocks/#{URI.encode(block_id, &URI.char_unreserved?/1)}/children",
      params: query
    )
    |> Response.handle_block_children_response()
  end

  defp build_children_query(params) do
    []
    |> maybe_put(:start_cursor, Map.get(params, :start_cursor))
    |> maybe_put(:page_size, Map.get(params, :page_size))
  end

  defp maybe_put(query, _key, nil), do: query
  defp maybe_put(query, key, value), do: Keyword.put(query, key, value)
end
