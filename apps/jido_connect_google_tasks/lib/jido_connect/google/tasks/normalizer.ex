defmodule Jido.Connect.Google.Tasks.Normalizer do
  @moduledoc "Normalizes Google Tasks API payloads into stable package structs."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.Tasks.{Task, TaskList}

  @doc "Normalizes a Google Tasks task-list payload."
  @spec task_list(map()) :: {:ok, TaskList.t()} | {:error, term()}
  def task_list(payload) when is_map(payload) do
    %{
      task_list_id: Data.get(payload, "id"),
      etag: Data.get(payload, "etag"),
      title: Data.get(payload, "title"),
      updated: Data.get(payload, "updated"),
      self_link: Data.get(payload, "selfLink"),
      metadata: %{}
    }
    |> Data.compact()
    |> TaskList.new()
  end

  def task_list(_payload), do: {:error, :invalid_task_list_payload}

  @doc "Normalizes a Google Tasks task payload."
  @spec task(map()) :: {:ok, Task.t()} | {:error, term()}
  def task(payload) when is_map(payload) do
    attrs = %{
      task_id: Data.get(payload, "id"),
      task_list_id: Data.get(payload, "task_list_id"),
      etag: Data.get(payload, "etag"),
      title: Data.get(payload, "title"),
      updated: Data.get(payload, "updated"),
      self_link: Data.get(payload, "selfLink"),
      parent: Data.get(payload, "parent"),
      position: Data.get(payload, "position"),
      notes: Data.get(payload, "notes"),
      status: Data.get(payload, "status"),
      due: Data.get(payload, "due"),
      completed: Data.get(payload, "completed"),
      deleted?: Data.get(payload, "deleted", false),
      hidden?: Data.get(payload, "hidden", false),
      links: normalize_links(Data.get(payload, "links", [])),
      web_view_link: Data.get(payload, "webViewLink"),
      metadata: %{}
    }

    attrs
    |> Data.compact()
    |> Task.new()
  end

  def task(_payload), do: {:error, :invalid_task_payload}

  defp normalize_links(links) when is_list(links) do
    Enum.map(links, &normalize_link/1)
  end

  defp normalize_links(_), do: []

  defp normalize_link(%{} = link) do
    %{
      type: Data.get(link, "type"),
      description: Data.get(link, "description"),
      link: Data.get(link, "link")
    }
  end

  defp normalize_link(_), do: %{}
end
