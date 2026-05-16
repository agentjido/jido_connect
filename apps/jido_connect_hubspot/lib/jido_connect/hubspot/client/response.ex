defmodule Jido.Connect.HubSpot.Client.Response do
  @moduledoc "HubSpot CRM v3 API response handling."

  alias Jido.Connect.Data
  alias Jido.Connect.HubSpot.Client.Transport
  alias Jido.Connect.HubSpot.Normalizer

  @doc "Handles a single CRM object get response."
  def handle_get_response({:ok, %{status: status, body: body}}, normalizer)
      when status in 200..299 and is_map(body) do
    case normalizer.(body) do
      {:ok, item} ->
        {:ok, item}

      {:error, _error} ->
        Transport.invalid_success_response("HubSpot CRM get response was invalid", body)
    end
  end

  def handle_get_response({:ok, %{status: status, body: body}}, _normalizer)
      when status in 200..299 do
    Transport.invalid_success_response("HubSpot CRM get response was invalid", body)
  end

  def handle_get_response(response, _normalizer), do: Transport.handle_error_response(response)

  @doc "Handles a CRM object list response with pagination."
  def handle_list_response({:ok, %{status: status, body: body}}, normalizer)
      when status in 200..299 and is_map(body) do
    with {:ok, items} <-
           normalize_items(
             body,
             "results",
             normalizer,
             "HubSpot CRM list response was invalid"
           ),
         {:ok, pagination} <- Normalizer.pagination(body) do
      result = %{
        items: items,
        pagination: pagination
      }

      {:ok, Data.compact(result)}
    end
  end

  def handle_list_response({:ok, %{status: status, body: body}}, _normalizer)
      when status in 200..299 do
    Transport.invalid_success_response("HubSpot CRM list response was invalid", body)
  end

  def handle_list_response(response, _normalizer), do: Transport.handle_error_response(response)

  @doc "Handles a CRM object search response with pagination."
  def handle_search_response({:ok, %{status: status, body: body}}, normalizer)
      when status in 200..299 and is_map(body) do
    with {:ok, items} <-
           normalize_items(
             body,
             "results",
             normalizer,
             "HubSpot CRM search response was invalid"
           ),
         {:ok, pagination} <- Normalizer.pagination(body) do
      result = %{
        items: items,
        pagination: pagination
      }

      {:ok, Data.compact(result)}
    end
  end

  def handle_search_response({:ok, %{status: status, body: body}}, _normalizer)
      when status in 200..299 do
    Transport.invalid_success_response("HubSpot CRM search response was invalid", body)
  end

  def handle_search_response(response, _normalizer), do: Transport.handle_error_response(response)

  defp normalize_items(body, key, normalizer, message) do
    case Data.get(body, key, []) do
      items when is_list(items) ->
        items
        |> Enum.reduce_while({:ok, []}, fn payload, {:ok, acc} ->
          case normalizer.(payload) do
            {:ok, item} -> {:cont, {:ok, [item | acc]}}
            {:error, _error} -> {:halt, Transport.invalid_success_response(message, body)}
          end
        end)
        |> case do
          {:ok, items} -> {:ok, Enum.reverse(items)}
          {:error, error} -> {:error, error}
        end

      _invalid ->
        Transport.invalid_success_response(message, body)
    end
  end
end
