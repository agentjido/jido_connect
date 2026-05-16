defmodule Jido.Connect.Airtable.Client.Response do
  @moduledoc "Airtable response handling."

  alias Jido.Connect.Data
  alias Jido.Connect.Airtable.Client.Transport
  alias Jido.Connect.Airtable.Normalizer

  @doc "Handles a list bases response."
  def handle_list_bases_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_items(
      body,
      "bases",
      &Normalizer.base/1,
      "Airtable list bases response was invalid"
    )
  end

  def handle_list_bases_response({:ok, %{status: _status, body: body}}) do
    Transport.invalid_success_response("Airtable list bases response was invalid", body)
  end

  def handle_list_bases_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a get base schema response."
  def handle_get_base_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Normalizer.base(body) do
      {:ok, base} ->
        {:ok, base}

      {:error, _error} ->
        Transport.invalid_success_response("Airtable base response was invalid", body)
    end
  end

  def handle_get_base_response({:ok, %{status: _status, body: body}}) do
    Transport.invalid_success_response("Airtable base response was invalid", body)
  end

  def handle_get_base_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a list records response."
  def handle_list_records_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, records} <-
           normalize_items(
             body,
             "records",
             &Normalizer.record/1,
             "Airtable list records response was invalid"
           ) do
      result = %{
        records: records,
        offset: Data.get(body, "offset")
      }

      {:ok, Data.compact(result)}
    end
  end

  def handle_list_records_response({:ok, %{status: _status, body: body}}) do
    Transport.invalid_success_response("Airtable list records response was invalid", body)
  end

  def handle_list_records_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a get record response."
  def handle_get_record_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Normalizer.record(body) do
      {:ok, record} ->
        {:ok, record}

      {:error, _error} ->
        Transport.invalid_success_response("Airtable record response was invalid", body)
    end
  end

  def handle_get_record_response({:ok, %{status: _status, body: body}}) do
    Transport.invalid_success_response("Airtable record response was invalid", body)
  end

  def handle_get_record_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a create record response."
  def handle_create_record_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Normalizer.record(body) do
      {:ok, record} ->
        {:ok, record}

      {:error, _error} ->
        Transport.invalid_success_response("Airtable create record response was invalid", body)
    end
  end

  def handle_create_record_response({:ok, %{status: _status, body: body}}) do
    Transport.invalid_success_response("Airtable create record response was invalid", body)
  end

  def handle_create_record_response(response), do: Transport.handle_error_response(response)

  @doc "Handles an update record response."
  def handle_update_record_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Normalizer.record(body) do
      {:ok, record} ->
        {:ok, record}

      {:error, _error} ->
        Transport.invalid_success_response("Airtable update record response was invalid", body)
    end
  end

  def handle_update_record_response({:ok, %{status: _status, body: body}}) do
    Transport.invalid_success_response("Airtable update record response was invalid", body)
  end

  def handle_update_record_response(response), do: Transport.handle_error_response(response)

  @doc "Handles a delete record response."
  def handle_delete_record_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Normalizer.record(body) do
      {:ok, record} ->
        {:ok, record}

      {:error, _error} ->
        Transport.invalid_success_response("Airtable delete record response was invalid", body)
    end
  end

  def handle_delete_record_response({:ok, %{status: _status, body: body}}) do
    Transport.invalid_success_response("Airtable delete record response was invalid", body)
  end

  def handle_delete_record_response(response), do: Transport.handle_error_response(response)

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
