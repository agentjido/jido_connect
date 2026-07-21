defmodule Jido.Connect.Google.Tasks.Client.Response do
  @moduledoc "Google Tasks response handling."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.Tasks.{Client.Transport, Normalizer}

  # --- Task list response handlers ---

  def handle_task_list_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, task_lists} <-
           normalize_items(
             body,
             "items",
             &Normalizer.task_list/1,
             "Google Tasks task list response was invalid"
           ) do
      {:ok,
       %{
         task_lists: task_lists,
         next_page_token: Data.get(body, "nextPageToken")
       }
       |> Data.compact()}
    end
  end

  def handle_task_list_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Tasks task list response was invalid", body)
  end

  def handle_task_list_list_response(response), do: Transport.handle_error_response(response)

  def handle_task_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.task_list/1, "Google Tasks response was invalid")
  end

  def handle_task_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Tasks response was invalid", body)
  end

  def handle_task_list_response(response), do: Transport.handle_error_response(response)

  def handle_task_list_delete_response({:ok, %{status: status}}, params)
      when status in 200..299 do
    {:ok, %{task_list_id: Data.get(params, :task_list_id), deleted?: true}}
  end

  def handle_task_list_delete_response(response, _params),
    do: Transport.handle_error_response(response)

  # --- Task response handlers ---

  def handle_task_collection_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    with {:ok, tasks} <-
           normalize_items(
             body,
             "items",
             &Normalizer.task/1,
             "Google Tasks task response was invalid"
           ) do
      {:ok,
       %{
         tasks: tasks,
         next_page_token: Data.get(body, "nextPageToken")
       }
       |> Data.compact()}
    end
  end

  def handle_task_collection_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Tasks task response was invalid", body)
  end

  def handle_task_collection_response(response), do: Transport.handle_error_response(response)

  def handle_task_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    normalize_one(body, &Normalizer.task/1, "Google Tasks task response was invalid")
  end

  def handle_task_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Google Tasks task response was invalid", body)
  end

  def handle_task_response(response), do: Transport.handle_error_response(response)

  def handle_task_delete_response({:ok, %{status: status}}, params)
      when status in 200..299 do
    {:ok,
     %{
       task_id: Data.get(params, :task_id),
       task_list_id: Data.get(params, :task_list_id),
       deleted?: true
     }}
  end

  def handle_task_delete_response(response, _params),
    do: Transport.handle_error_response(response)

  def handle_task_clear_response({:ok, %{status: status}}, params)
      when status in 200..299 do
    {:ok, %{task_list_id: Data.get(params, :task_list_id), cleared?: true}}
  end

  def handle_task_clear_response(response, _params),
    do: Transport.handle_error_response(response)

  defp normalize_one(body, normalizer, message) do
    case normalizer.(body) do
      {:ok, item} -> {:ok, item}
      {:error, _error} -> Transport.invalid_success_response(message, body)
    end
  end

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
