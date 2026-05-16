defmodule Jido.Connect.Calendly.Client.Response do
  @moduledoc "Calendly response handling helpers."

  alias Jido.Connect.Calendly.Client.Transport

  @doc "Handles a generic paginated list response."
  def handle_list_response({:ok, %{status: status, body: body}}, normalizer, entity_name)
      when status in 200..299 and is_map(body) do
    case normalizer.(body) do
      {:ok, result} ->
        {:ok, result}

      {:error, _error} ->
        Transport.invalid_success_response("Calendly #{entity_name} response was invalid", body)
    end
  end

  def handle_list_response({:ok, %{status: status, body: body}}, _normalizer, entity_name)
      when status in 200..299 do
    Transport.invalid_success_response("Calendly #{entity_name} response was invalid", body)
  end

  def handle_list_response(response, _normalizer, _entity_name),
    do: Transport.handle_error_response(response)

  @doc "Handles a single-entity response."
  def handle_entity_response({:ok, %{status: status, body: body}}, normalizer, entity_name)
      when status in 200..299 and is_map(body) do
    case normalizer.(body) do
      {:ok, result} ->
        {:ok, result}

      {:error, _error} ->
        Transport.invalid_success_response("Calendly #{entity_name} response was invalid", body)
    end
  end

  def handle_entity_response({:ok, %{status: status, body: body}}, _normalizer, entity_name)
      when status in 200..299 do
    Transport.invalid_success_response("Calendly #{entity_name} response was invalid", body)
  end

  def handle_entity_response(response, _normalizer, _entity_name),
    do: Transport.handle_error_response(response)

  @doc "Handles a delete response (204 No Content or 200 with body)."
  def handle_delete_response({:ok, %{status: 204}}, entity_name) do
    {:ok, %{deleted: true, entity: entity_name}}
  end

  def handle_delete_response({:ok, %{status: status, body: body}}, entity_name)
      when status in 200..299 and is_map(body) do
    {:ok, %{deleted: true, entity: entity_name, body: body}}
  end

  def handle_delete_response({:ok, %{status: status}}, entity_name)
      when status in 200..299 do
    {:ok, %{deleted: true, entity: entity_name}}
  end

  def handle_delete_response(response, _entity_name),
    do: Transport.handle_error_response(response)
end
