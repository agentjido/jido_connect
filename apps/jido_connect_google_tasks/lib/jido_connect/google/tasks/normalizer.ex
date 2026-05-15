defmodule Jido.Connect.Google.Tasks.Normalizer do
  @moduledoc "Normalizes Google Tasks API payloads into stable package structs."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.Tasks.TaskList

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
end
