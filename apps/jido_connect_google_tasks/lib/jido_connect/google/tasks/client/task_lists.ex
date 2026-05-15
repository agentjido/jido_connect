defmodule Jido.Connect.Google.Tasks.Client.TaskLists do
  @moduledoc "Google Tasks tasklists API boundary."

  alias Jido.Connect.Google.Tasks.Client.{Response, Transport}

  @default_page_size 20
  @max_page_size 100

  def list_task_lists(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.tasks_request()
    |> Req.get(
      url: "/tasks/v1/users/@me/lists",
      params: list_params(params)
    )
    |> Response.handle_task_list_list_response()
  end

  def get_task_list(%{task_list_id: task_list_id} = params, access_token)
      when is_binary(task_list_id) and is_binary(access_token) do
    access_token
    |> Transport.tasks_request()
    |> Req.get(
      url: "/tasks/v1/users/@me/lists/#{encode_id(task_list_id)}",
      params: get_params(params)
    )
    |> Response.handle_task_list_response()
  end

  def create_task_list(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.tasks_request()
    |> Req.post(
      url: "/tasks/v1/users/@me/lists",
      json: task_list_body(params)
    )
    |> Response.handle_task_list_response()
  end

  def update_task_list(%{task_list_id: task_list_id} = params, access_token)
      when is_binary(task_list_id) and is_binary(access_token) do
    access_token
    |> Transport.tasks_request()
    |> Req.put(
      url: "/tasks/v1/users/@me/lists/#{encode_id(task_list_id)}",
      json: task_list_body(params)
    )
    |> Response.handle_task_list_response()
  end

  def delete_task_list(%{task_list_id: task_list_id} = params, access_token)
      when is_binary(task_list_id) and is_binary(access_token) do
    access_token
    |> Transport.tasks_request()
    |> Req.delete(url: "/tasks/v1/users/@me/lists/#{encode_id(task_list_id)}")
    |> Response.handle_task_list_delete_response(params)
  end

  defp list_params(params) do
    page_size = min(Map.get(params, :page_size, @default_page_size), @max_page_size)

    %{}
    |> maybe_put(:maxResults, page_size)
    |> maybe_put(:pageToken, Map.get(params, :page_token))
    |> maybe_put(:fields, Map.get(params, :fields))
  end

  defp get_params(params) do
    %{}
    |> maybe_put(:fields, Map.get(params, :fields))
  end

  defp task_list_body(params) do
    %{}
    |> maybe_put(:title, Map.get(params, :title))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp encode_id(id), do: URI.encode(id, &URI.char_unreserved?/1)
end
