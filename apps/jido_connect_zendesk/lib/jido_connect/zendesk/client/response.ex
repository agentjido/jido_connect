defmodule Jido.Connect.Zendesk.Client.Response do
  @moduledoc "Zendesk REST success and error response handling."

  alias Jido.Connect.Zendesk.Client.{Normalizer, Transport}

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

  @doc "Handles a Zendesk search response (uses `results` key for search endpoints)."
  def handle_search_response({:ok, %{status: status, body: body}}, key)
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
        Transport.invalid_success_response("Zendesk search response was invalid", body)
    end
  end

  def handle_search_response({:ok, %{status: status, body: body}}, _key)
      when status in 200..299 do
    Transport.invalid_success_response("Zendesk search response was invalid", body)
  end

  def handle_search_response(response, _key), do: Transport.handle_error_response(response)

  @doc "Handles a single Zendesk ticket get response."
  def handle_ticket_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Map.get(body, "ticket") do
      ticket when is_map(ticket) ->
        case Normalizer.ticket(ticket) do
          {:ok, struct} -> {:ok, Map.from_struct(struct) |> Map.drop([:metadata])}
          error -> error
        end

      _other ->
        Transport.invalid_success_response("Zendesk ticket response was invalid", body)
    end
  end

  def handle_ticket_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    Transport.invalid_success_response("Zendesk ticket response was invalid", body)
  end

  def handle_ticket_response(response), do: Transport.handle_error_response(response)
end
