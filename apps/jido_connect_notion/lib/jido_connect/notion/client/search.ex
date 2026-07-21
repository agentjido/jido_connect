defmodule Jido.Connect.Notion.Client.Search do
  @moduledoc "Notion search API boundary."

  alias Jido.Connect.Notion.Client.{Response, Transport}

  @spec search(map(), String.t()) :: {:ok, map()} | {:error, term()}
  def search(params, access_token) when is_map(params) and is_binary(access_token) do
    body = build_search_body(params)

    access_token
    |> Transport.request()
    |> Req.post(url: "/search", json: body)
    |> Response.handle_search_response()
  end

  defp build_search_body(params) do
    body = %{}

    body =
      case Map.get(params, :query) do
        nil -> body
        query -> Map.put(body, "query", query)
      end

    body =
      case Map.get(params, :filter) do
        nil -> body
        filter -> Map.put(body, "filter", filter)
      end

    body =
      case Map.get(params, :sort) do
        nil -> body
        sort -> Map.put(body, "sort", sort)
      end

    body =
      case Map.get(params, :start_cursor) do
        nil -> body
        cursor -> Map.put(body, "start_cursor", cursor)
      end

    body =
      case Map.get(params, :page_size) do
        nil -> body
        size -> Map.put(body, "page_size", size)
      end

    body
  end
end
