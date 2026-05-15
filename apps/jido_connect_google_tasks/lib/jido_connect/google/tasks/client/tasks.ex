defmodule Jido.Connect.Google.Tasks.Client.Tasks do
  @moduledoc "Google Tasks tasks API boundary."

  alias Jido.Connect.Google.Tasks.Client.{Response, Transport}

  @default_page_size 20
  @max_page_size 100

  def list_tasks(params, access_token) when is_map(params) and is_binary(access_token) do
    task_list_id = Map.fetch!(params, :task_list_id)

    access_token
    |> Transport.tasks_request()
    |> Req.get(
      url: "/tasks/v1/lists/#{encode_id(task_list_id)}/tasks",
      params: list_params(params)
    )
    |> Response.handle_task_collection_response()
  end

  def get_task(params, access_token) when is_map(params) and is_binary(access_token) do
    task_list_id = Map.fetch!(params, :task_list_id)
    task_id = Map.fetch!(params, :task_id)

    access_token
    |> Transport.tasks_request()
    |> Req.get(
      url: "/tasks/v1/lists/#{encode_id(task_list_id)}/tasks/#{encode_id(task_id)}",
      params: get_params(params)
    )
    |> Response.handle_task_response()
  end

  def create_task(params, access_token) when is_map(params) and is_binary(access_token) do
    task_list_id = Map.fetch!(params, :task_list_id)

    access_token
    |> Transport.tasks_request()
    |> Req.post(
      url: "/tasks/v1/lists/#{encode_id(task_list_id)}/tasks",
      json: task_body(params)
    )
    |> Response.handle_task_response()
  end

  def update_task(params, access_token) when is_map(params) and is_binary(access_token) do
    task_list_id = Map.fetch!(params, :task_list_id)
    task_id = Map.fetch!(params, :task_id)

    access_token
    |> Transport.tasks_request()
    |> Req.put(
      url: "/tasks/v1/lists/#{encode_id(task_list_id)}/tasks/#{encode_id(task_id)}",
      json: task_body(params)
    )
    |> Response.handle_task_response()
  end

  def delete_task(params, access_token) when is_map(params) and is_binary(access_token) do
    task_list_id = Map.fetch!(params, :task_list_id)
    task_id = Map.fetch!(params, :task_id)

    access_token
    |> Transport.tasks_request()
    |> Req.delete(url: "/tasks/v1/lists/#{encode_id(task_list_id)}/tasks/#{encode_id(task_id)}")
    |> Response.handle_task_delete_response(params)
  end

  def clear_tasks(params, access_token) when is_map(params) and is_binary(access_token) do
    task_list_id = Map.fetch!(params, :task_list_id)

    access_token
    |> Transport.tasks_request()
    |> Req.post(
      url: "/tasks/v1/lists/#{encode_id(task_list_id)}/clear",
      json: %{}
    )
    |> Response.handle_task_clear_response(params)
  end

  def move_task(params, access_token) when is_map(params) and is_binary(access_token) do
    task_list_id = Map.fetch!(params, :task_list_id)
    task_id = Map.fetch!(params, :task_id)

    access_token
    |> Transport.tasks_request()
    |> Req.post(
      url: "/tasks/v1/lists/#{encode_id(task_list_id)}/tasks/#{encode_id(task_id)}/move",
      params: move_params(params)
    )
    |> Response.handle_task_response()
  end

  defp list_params(params) do
    page_size = min(Map.get(params, :page_size, @default_page_size), @max_page_size)

    %{}
    |> maybe_put(:maxResults, page_size)
    |> maybe_put(:pageToken, Map.get(params, :page_token))
    |> maybe_put(:fields, Map.get(params, :fields))
    |> maybe_put(:showCompleted, Map.get(params, :show_completed))
    |> maybe_put(:showDeleted, Map.get(params, :show_deleted))
    |> maybe_put(:showHidden, Map.get(params, :show_hidden))
    |> maybe_put(:completedMin, Map.get(params, :completed_min))
    |> maybe_put(:completedMax, Map.get(params, :completed_max))
    |> maybe_put(:dueMin, Map.get(params, :due_min))
    |> maybe_put(:dueMax, Map.get(params, :due_max))
    |> maybe_put(:updatedMin, Map.get(params, :updated_min))
  end

  defp get_params(params) do
    %{}
    |> maybe_put(:fields, Map.get(params, :fields))
  end

  defp task_body(params) do
    %{}
    |> maybe_put(:id, Map.get(params, :task_id))
    |> maybe_put(:title, Map.get(params, :title))
    |> maybe_put(:notes, Map.get(params, :notes))
    |> maybe_put(:status, Map.get(params, :status))
    |> maybe_put(:due, Map.get(params, :due))
    |> maybe_put(:completed, Map.get(params, :completed))
    |> maybe_put(:parent, Map.get(params, :parent))
    |> maybe_put(:position, Map.get(params, :position))
    |> maybe_put(:links, Map.get(params, :links))
  end

  defp move_params(params) do
    %{}
    |> maybe_put(:parent, Map.get(params, :destination_parent))
    |> maybe_put(:position, Map.get(params, :destination_position))
    |> maybe_put(:destTaskList, Map.get(params, :destination_task_list_id))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp encode_id(id), do: URI.encode(id, &URI.char_unreserved?/1)
end
