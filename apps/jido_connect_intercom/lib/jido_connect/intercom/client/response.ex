defmodule Jido.Connect.Intercom.Client.Response do
  @moduledoc "Intercom REST success and error response handling."

  alias Jido.Connect.Intercom.Client.{Normalizer, Transport}

  @doc "Handles an Intercom list response with scroll-based pagination."
  def handle_list_response({:ok, %{status: status, body: body}}, key)
      when status in 200..299 and is_map(body) do
    case Map.get(body, key) do
      items when is_list(items) ->
        {:ok,
         %{
           items: items,
           pagination: extract_pagination(body)
         }}

      _other ->
        Transport.invalid_success_response("Intercom list response was invalid", body)
    end
  end

  def handle_list_response({:ok, %{status: status, body: body}}, _key)
      when status in 200..299 do
    Transport.invalid_success_response("Intercom list response was invalid", body)
  end

  def handle_list_response(response, _key), do: Transport.handle_error_response(response)

  @doc "Handles an Intercom search response with scroll-based pagination."
  def handle_search_response({:ok, %{status: status, body: body}}, key)
      when status in 200..299 and is_map(body) do
    case Map.get(body, key) do
      items when is_list(items) ->
        {:ok,
         %{
           items: items,
           pagination: extract_pagination(body),
           total_count: Map.get(body, "total_count")
         }}

      _other ->
        Transport.invalid_success_response("Intercom search response was invalid", body)
    end
  end

  def handle_search_response({:ok, %{status: status, body: body}}, _key)
      when status in 200..299 do
    Transport.invalid_success_response("Intercom search response was invalid", body)
  end

  def handle_search_response(response, _key), do: Transport.handle_error_response(response)

  @doc "Handles a single Intercom resource get response."
  def handle_single_response({:ok, %{status: status, body: body}}, key, normalizer_fn)
      when status in 200..299 and is_map(body) and is_function(normalizer_fn, 1) do
    case Map.get(body, key) do
      item when is_map(item) ->
        normalizer_fn.(item)

      _other ->
        Transport.invalid_success_response("Intercom response was invalid", body)
    end
  end

  def handle_single_response({:ok, %{status: status, body: body}}, _key, _normalizer_fn)
      when status in 200..299 do
    Transport.invalid_success_response("Intercom response was invalid", body)
  end

  def handle_single_response(response, _key, _normalizer_fn),
    do: Transport.handle_error_response(response)

  defp extract_pagination(body) do
    case Normalizer.pagination(body) do
      {:ok, page} -> Map.from_struct(page) |> Map.drop([:metadata])
      {:error, _} -> nil
    end
  end
end
