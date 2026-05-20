defmodule Jido.Connect.Asana.Client.Response do
  @moduledoc "Asana REST API success and error response handling."

  alias Jido.Connect.Asana.Client.Transport
  alias Jido.Connect.Asana.Normalizer

  # ---------------------------------------------------------------------------
  # Workspaces
  # ---------------------------------------------------------------------------

  @doc "Handles an Asana workspace list response."
  def handle_workspace_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Map.get(body, "data") do
      items when is_list(items) ->
        with {:ok, normalized} <- normalize_workspaces(items) do
          {:ok, %{items: normalized, pagination: extract_pagination(body)}}
        end

      _other ->
        Transport.invalid_success_response("Asana workspace list response was invalid", body)
    end
  end

  def handle_workspace_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Asana workspace list response was invalid", body)
  end

  def handle_workspace_list_response(response), do: Transport.handle_error_response(response)

  # ---------------------------------------------------------------------------
  # Projects
  # ---------------------------------------------------------------------------

  @doc "Handles an Asana project list response."
  def handle_project_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Map.get(body, "data") do
      items when is_list(items) ->
        with {:ok, normalized} <- normalize_projects(items) do
          {:ok, %{items: normalized, pagination: extract_pagination(body)}}
        end

      _other ->
        Transport.invalid_success_response("Asana project list response was invalid", body)
    end
  end

  def handle_project_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Asana project list response was invalid", body)
  end

  def handle_project_list_response(response), do: Transport.handle_error_response(response)

  # ---------------------------------------------------------------------------
  # Tasks
  # ---------------------------------------------------------------------------

  @doc "Handles an Asana task list response."
  def handle_task_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Map.get(body, "data") do
      items when is_list(items) ->
        with {:ok, normalized} <- normalize_tasks(items) do
          {:ok, %{items: normalized, pagination: extract_pagination(body)}}
        end

      _other ->
        Transport.invalid_success_response("Asana task list response was invalid", body)
    end
  end

  def handle_task_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Asana task list response was invalid", body)
  end

  def handle_task_list_response(response), do: Transport.handle_error_response(response)

  @doc "Handles an Asana single task get response."
  def handle_task_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Map.get(body, "data") do
      item when is_map(item) ->
        Normalizer.task(item)

      _other ->
        Transport.invalid_success_response("Asana task response was invalid", body)
    end
  end

  def handle_task_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    Transport.invalid_success_response("Asana task response was invalid", body)
  end

  def handle_task_response(response), do: Transport.handle_error_response(response)

  # ---------------------------------------------------------------------------
  # Stories
  # ---------------------------------------------------------------------------

  @doc "Handles an Asana story list response."
  def handle_story_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Map.get(body, "data") do
      items when is_list(items) ->
        with {:ok, normalized} <- normalize_stories(items) do
          {:ok, %{items: normalized, pagination: extract_pagination(body)}}
        end

      _other ->
        Transport.invalid_success_response("Asana story list response was invalid", body)
    end
  end

  def handle_story_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Asana story list response was invalid", body)
  end

  def handle_story_list_response(response), do: Transport.handle_error_response(response)

  # ---------------------------------------------------------------------------
  # Users
  # ---------------------------------------------------------------------------

  @doc "Handles an Asana single user get response."
  def handle_user_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Map.get(body, "data") do
      item when is_map(item) ->
        Normalizer.user(item)

      _other ->
        Transport.invalid_success_response("Asana user response was invalid", body)
    end
  end

  def handle_user_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    Transport.invalid_success_response("Asana user response was invalid", body)
  end

  def handle_user_response(response), do: Transport.handle_error_response(response)

  @doc "Handles an Asana user list response."
  def handle_user_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 and is_map(body) do
    case Map.get(body, "data") do
      items when is_list(items) ->
        with {:ok, normalized} <- normalize_users(items) do
          {:ok, %{items: normalized, pagination: extract_pagination(body)}}
        end

      _other ->
        Transport.invalid_success_response("Asana user list response was invalid", body)
    end
  end

  def handle_user_list_response({:ok, %{status: status, body: body}})
      when status in 200..299 do
    Transport.invalid_success_response("Asana user list response was invalid", body)
  end

  def handle_user_list_response(response), do: Transport.handle_error_response(response)

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp extract_pagination(body) do
    case Normalizer.pagination(body) do
      {:ok, page} -> Map.from_struct(page) |> Map.drop([:metadata])
      {:error, _} -> nil
    end
  end

  defp normalize_workspaces(items) do
    reduce_normalized(items, &Normalizer.workspace/1)
  end

  defp normalize_projects(items) do
    reduce_normalized(items, &Normalizer.project/1)
  end

  defp normalize_tasks(items) do
    reduce_normalized(items, &Normalizer.task/1)
  end

  defp normalize_stories(items) do
    reduce_normalized(items, &Normalizer.story/1)
  end

  defp normalize_users(items) do
    reduce_normalized(items, &Normalizer.user/1)
  end

  defp reduce_normalized(items, normalizer_fn)
       when is_list(items) and is_function(normalizer_fn, 1) do
    items
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
      case normalizer_fn.(item) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, Enum.reverse(items)}
      {:error, reason} -> {:error, reason}
    end
  end
end
