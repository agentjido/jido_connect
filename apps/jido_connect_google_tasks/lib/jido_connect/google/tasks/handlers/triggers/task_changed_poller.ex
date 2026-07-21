defmodule Jido.Connect.Google.Tasks.Handlers.Triggers.TaskChangedPoller do
  @moduledoc false

  alias Jido.Connect.Google.Checkpoint
  alias Jido.Connect.Google.Tasks.Client

  @doc """
  Polls for changed Google Tasks within a task list.

  Google Tasks API does not support sync tokens (unlike Calendar or Contacts).
  Instead, this trigger uses the `updatedMin` timestamp parameter as a
  checkpoint:

    * On the first poll (no checkpoint), a full snapshot is taken with
      `showDeleted: true` but no signals are emitted. The latest `updated`
      timestamp across all returned tasks becomes the initial checkpoint.

    * On subsequent polls, `updatedMin` is set to the checkpoint and tasks
      modified at or after that time are fetched. Each task produces a signal.
      The new checkpoint is the latest `updated` value from the response.

  Checkpoint semantics are sound because:

    * The `updated` field is an RFC 3339 timestamp set by the server on every
      modification.
    * Using `>=` ensures no task is missed when multiple tasks share the same
      timestamp; deduplication by `task_id + updated` prevents double-emission.
    * Deleted tasks (`deleted: true`) are included via `showDeleted: true` so
      consumers can process removals.
  """
  def poll(config, %{credentials: credentials, checkpoint: checkpoint}) do
    with {:ok, client} <- fetch_client(credentials) do
      config = normalize_config(config)
      access_token = Map.get(credentials, :access_token)

      if checkpoint in [nil, ""] do
        initialize_checkpoint(client, config, access_token)
      else
        poll_changes(client, config, checkpoint, access_token)
      end
    end
  end

  defp initialize_checkpoint(client, config, access_token) do
    fetch_task_pages(client, config, access_token, [], nil, MapSet.new(), emit?: false)
  end

  defp poll_changes(client, config, checkpoint, access_token) do
    params =
      config
      |> Map.put(:updated_min, checkpoint)
      |> Map.put(:show_deleted, true)

    fetch_task_pages(client, params, access_token, [], nil, MapSet.new(), emit?: true)
  end

  defp fetch_task_pages(client, params, access_token, signals, latest_updated, seen, opts) do
    with {:ok, result} <- client.list_tasks(params, access_token) do
      tasks = Map.get(result, :tasks, [])
      emit? = Keyword.fetch!(opts, :emit?)

      signals =
        if emit? do
          signals ++ Enum.map(tasks, &normalize_signal/1)
        else
          signals
        end

      latest_updated = latest_updated_from_tasks(tasks) || latest_updated

      case Map.get(result, :next_page_token) do
        nil ->
          checkpoint = latest_updated || Map.get(params, :updated_min)

          if checkpoint in [nil, ""] do
            invalid_missing_checkpoint()
          else
            {:ok, %{signals: dedupe_signals(signals), checkpoint: checkpoint}}
          end

        page_token ->
          if MapSet.member?(seen, page_token) do
            invalid_repeated_page_token(page_token)
          else
            fetch_task_pages(
              client,
              Map.put(params, :page_token, page_token),
              access_token,
              signals,
              latest_updated,
              MapSet.put(seen, page_token),
              opts
            )
          end
      end
    end
  end

  defp normalize_config(config) do
    config
    |> Map.put_new(:page_size, 100)
    |> Map.put_new(:show_deleted, true)
  end

  defp normalize_signal(task) do
    %{
      task_id: Map.get(task, :task_id),
      task_list_id: Map.get(task, :task_list_id),
      title: Map.get(task, :title),
      status: Map.get(task, :status),
      change_type: change_type(task),
      due: Map.get(task, :due),
      completed: Map.get(task, :completed),
      updated: Map.get(task, :updated),
      task: public_map(task)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp change_type(%{deleted?: true}), do: "deleted"
  defp change_type(%{status: "completed"}), do: "completed"
  defp change_type(_task), do: "updated"

  defp latest_updated_from_tasks(tasks) when is_list(tasks) do
    tasks
    |> Enum.map(&Map.get(&1, :updated))
    |> Enum.reject(&is_nil/1)
    |> Enum.sort(:desc)
    |> List.first()
  end

  defp dedupe_signals(signals) do
    {_seen, unique} =
      Enum.reduce(signals, {MapSet.new(), []}, fn signal, {seen, acc} ->
        key = {Map.get(signal, :task_id), Map.get(signal, :updated)}

        cond do
          key == {nil, nil} ->
            {seen, acc}

          MapSet.member?(seen, key) ->
            {seen, acc}

          true ->
            {MapSet.put(seen, key), [signal | acc]}
        end
      end)

    Enum.reverse(unique)
  end

  defp invalid_missing_checkpoint do
    Checkpoint.invalid_response(
      "Google Tasks task list response contained no tasks with updated timestamps"
    )
  end

  defp invalid_repeated_page_token(page_token) do
    Checkpoint.invalid_response("Google Tasks task list response repeated nextPageToken", %{
      next_page_token: page_token
    })
  end

  defp public_map(struct) when is_struct(struct), do: struct |> Map.from_struct() |> public_map()
  defp public_map(map) when is_map(map), do: map
  defp public_map(value), do: value

  defp fetch_client(%{google_tasks_client: client}) when is_atom(client), do: {:ok, client}
  defp fetch_client(_credentials), do: {:ok, Client}
end
