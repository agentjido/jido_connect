defmodule Jido.Connect.Notion.Client.Pages do
  @moduledoc "Notion page read and write API boundary."

  alias Jido.Connect.Notion.Client.{Response, Transport}

  @spec get_page(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_page(page_id, access_token)
      when is_binary(page_id) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/pages/#{URI.encode(page_id, &URI.char_unreserved?/1)}")
    |> Response.handle_page_response()
  end

  @spec create_page(map(), String.t()) :: {:ok, map()} | {:error, term()}
  def create_page(params, access_token) when is_map(params) and is_binary(access_token) do
    body = build_page_body(params)

    access_token
    |> Transport.request()
    |> Req.post(url: "/pages", json: body)
    |> Response.handle_page_response()
  end

  @spec update_page(String.t(), map(), String.t()) :: {:ok, map()} | {:error, term()}
  def update_page(page_id, params, access_token)
      when is_binary(page_id) and is_map(params) and is_binary(access_token) do
    body = build_page_body(params)

    access_token
    |> Transport.request()
    |> Req.patch(
      url: "/pages/#{URI.encode(page_id, &URI.char_unreserved?/1)}",
      json: body
    )
    |> Response.handle_page_response()
  end

  defp build_page_body(params) do
    body = %{}

    body =
      case Map.get(params, :parent) do
        nil -> body
        parent -> Map.put(body, "parent", parent)
      end

    body =
      case Map.get(params, :properties) do
        nil -> body
        properties -> Map.put(body, "properties", properties)
      end

    body =
      case Map.get(params, :children) do
        nil -> body
        children -> Map.put(body, "children", children)
      end

    body =
      case Map.get(params, :archived) do
        nil -> body
        archived -> Map.put(body, "archived", archived)
      end

    body =
      case Map.get(params, :cover) do
        nil -> body
        cover -> Map.put(body, "cover", cover)
      end

    body =
      case Map.get(params, :icon) do
        nil -> body
        icon -> Map.put(body, "icon", icon)
      end

    body
  end
end
