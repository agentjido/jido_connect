defmodule Jido.Connect.Notion.Client.Blocks do
  @moduledoc "Notion block read and write API boundary."

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

  @spec append_block_children(String.t(), map(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def append_block_children(block_id, params, access_token)
      when is_binary(block_id) and is_map(params) and is_binary(access_token) do
    body = build_append_body(params)

    access_token
    |> Transport.request()
    |> Req.patch(
      url: "/blocks/#{URI.encode(block_id, &URI.char_unreserved?/1)}/children",
      json: body
    )
    |> Response.handle_block_children_response()
  end

  @spec update_block(String.t(), map(), String.t()) :: {:ok, map()} | {:error, term()}
  def update_block(block_id, params, access_token)
      when is_binary(block_id) and is_map(params) and is_binary(access_token) do
    body = build_update_body(params)

    access_token
    |> Transport.request()
    |> Req.patch(
      url: "/blocks/#{URI.encode(block_id, &URI.char_unreserved?/1)}",
      json: body
    )
    |> Response.handle_block_response()
  end

  @spec archive_block(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def archive_block(block_id, access_token)
      when is_binary(block_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.patch(
      url: "/blocks/#{URI.encode(block_id, &URI.char_unreserved?/1)}",
      json: %{archived: true}
    )
    |> Response.handle_block_response()
  end

  defp build_children_query(params) do
    []
    |> maybe_put(:start_cursor, Map.get(params, :start_cursor))
    |> maybe_put(:page_size, Map.get(params, :page_size))
  end

  defp build_append_body(params) do
    body = %{}

    body =
      case Map.get(params, :children) do
        nil -> body
        children -> Map.put(body, "children", children)
      end

    body =
      case Map.get(params, :after) do
        nil -> body
        after_id -> Map.put(body, "after", after_id)
      end

    body
  end

  defp build_update_body(params) do
    body = %{}

    body =
      case Map.get(params, :archived) do
        nil -> body
        archived -> Map.put(body, "archived", archived)
      end

    case Map.get(params, :type) do
      nil -> body
      type -> put_type_data(body, params, type)
    end
  end

  defp put_type_data(body, params, type) do
    case Map.get(params, String.to_existing_atom(type)) do
      nil -> body
      type_data -> Map.put(body, type, type_data)
    end
  rescue
    ArgumentError -> body
  end

  defp maybe_put(query, _key, nil), do: query
  defp maybe_put(query, key, value), do: Keyword.put(query, key, value)
end
