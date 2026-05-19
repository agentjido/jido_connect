defmodule Jido.Connect.Zendesk.Client.Response do
  @moduledoc "Zendesk REST success and error response handling."

  alias Jido.Connect.Zendesk.Client.Transport

  @doc "Handles a generic Zendesk map response."
  def handle_map_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    {:ok, body}
  end

  def handle_map_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    Transport.invalid_success_response("Zendesk response was invalid", body)
  end

  def handle_map_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a Zendesk list response with pagination."
  def handle_list_response({:ok, %{status: status, body: body}}, key)
      when status in 200..299 and is_map(body) do
    case Map.get(body, key) do
      items when is_list(items) ->
        {:ok,
         %{
           items: items,
           next_page: Map.get(body, "next_page"),
           previous_page: Map.get(body, "previous_page"),
           count: Map.get(body, "count")
         }}

      _other ->
        Transport.invalid_success_response("Zendesk list response was invalid", body)
    end
  end

  def handle_list_response({:ok, %{status: status, body: body}}, _key)
      when status in 200..299 do
    Transport.invalid_success_response("Zendesk list response was invalid", body)
  end

  def handle_list_response(response, _key), do: Transport.handle_error_response(response)
end
