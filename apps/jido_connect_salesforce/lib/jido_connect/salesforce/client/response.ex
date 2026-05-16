defmodule Jido.Connect.Salesforce.Client.Response do
  @moduledoc "Salesforce REST API response handling."

  alias Jido.Connect.Data
  alias Jido.Connect.Salesforce.Client.Transport

  @doc "Handles a single SObject get response."
  def handle_get_response({:ok, %{status: status, body: body}}, normalizer)
      when status in 200..299 and is_map(body) do
    case normalizer.(body) do
      {:ok, item} ->
        {:ok, item}

      {:error, _error} ->
        Transport.invalid_success_response("Salesforce get response was invalid", body)
    end
  end

  def handle_get_response({:ok, %{status: status, body: body}}, _normalizer)
      when status in 200..299 do
    Transport.invalid_success_response("Salesforce get response was invalid", body)
  end

  def handle_get_response(response, _normalizer), do: Transport.handle_error_response(response)

  @doc "Handles a Salesforce SOQL query response with pagination."
  def handle_list_response({:ok, %{status: status, body: body}}, normalizer)
      when status in 200..299 and is_map(body) do
    with {:ok, items} <-
           normalize_items(
             body,
             "records",
             normalizer,
             "Salesforce list response was invalid"
           ),
         {:ok, pagination} <- pagination(body) do
      result = %{
        items: items,
        pagination: pagination
      }

      {:ok, Data.compact(result)}
    end
  end

  def handle_list_response({:ok, %{status: status, body: body}}, _normalizer)
      when status in 200..299 do
    Transport.invalid_success_response("Salesforce list response was invalid", body)
  end

  def handle_list_response(response, _normalizer), do: Transport.handle_error_response(response)

  defp pagination(body) when is_map(body) do
    {:ok,
     %{
       total_size: Map.get(body, "totalSize"),
       done: Map.get(body, "done", true),
       next_records_url: Map.get(body, "nextRecordsUrl")
     }
     |> Data.compact()}
  end

  defp pagination(_body), do: {:ok, nil}

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
