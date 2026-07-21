defmodule Jido.Connect.Notion.Client.Databases do
  @moduledoc "Notion database read and query API boundary."

  alias Jido.Connect.Notion.Client.{Response, Transport}

  @spec get_database(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_database(database_id, access_token)
      when is_binary(database_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/databases/#{URI.encode(database_id, &URI.char_unreserved?/1)}")
    |> Response.handle_database_response()
  end

  @spec query_database(String.t(), map(), String.t()) :: {:ok, map()} | {:error, term()}
  def query_database(database_id, params, access_token)
      when is_binary(database_id) and is_map(params) and is_binary(access_token) do
    body = build_query_body(params)

    access_token
    |> Transport.request()
    |> Req.post(
      url: "/databases/#{URI.encode(database_id, &URI.char_unreserved?/1)}/query",
      json: body
    )
    |> Response.handle_query_database_response()
  end

  defp build_query_body(params) do
    body = %{}

    body =
      case Map.get(params, :filter) do
        nil -> body
        filter -> Map.put(body, "filter", filter)
      end

    body =
      case Map.get(params, :sorts) do
        nil -> body
        sorts -> Map.put(body, "sorts", sorts)
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
