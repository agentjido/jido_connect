defmodule Jido.Connect.Google.Tasks.Handlers.Triggers.TaskChangedPollerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Tasks.Handlers.Triggers.TaskChangedPoller
  alias Jido.Connect.Google.Tasks.Task

  @task_list_id "list_1"

  defmodule FakeClient do
    # --- Initial full-scan pages (no updated_min) ---

    def list_tasks(%{task_list_id: "list_1", page_token: "page_2"} = params, "token")
        when not is_map_key(params, :updated_min) do
      {:ok,
       %{
         tasks: [
           Task.new!(%{
             task_id: "task_3",
             task_list_id: "list_1",
             title: "Review PR",
             status: "needsAction",
             updated: "2026-05-15T12:00:00.000Z"
           })
         ]
       }}
    end

    def list_tasks(%{task_list_id: "list_1"} = params, "token")
        when not is_map_key(params, :updated_min) do
      {:ok,
       %{
         tasks: [
           Task.new!(%{
             task_id: "task_1",
             task_list_id: "list_1",
             title: "Buy groceries",
             status: "needsAction",
             updated: "2026-05-14T09:30:00.000Z"
           }),
           Task.new!(%{
             task_id: "task_2",
             task_list_id: "list_1",
             title: "Write report",
             status: "completed",
             updated: "2026-05-15T10:00:00.000Z"
           })
         ],
         next_page_token: "page_2"
       }}
    end

    # --- Changed-task pages (with updated_min) ---

    def list_tasks(
          %{
            task_list_id: "list_1",
            updated_min: "2026-05-15T10:00:00.000Z",
            page_token: "page_2"
          },
          "token"
        ) do
      {:ok,
       %{
         tasks: [
           Task.new!(%{
             task_id: "task_1",
             task_list_id: "list_1",
             title: "Buy groceries (deleted)",
             status: "needsAction",
             updated: "2026-05-15T12:00:00.000Z",
             deleted?: true
           })
         ]
       }}
    end

    def list_tasks(
          %{task_list_id: "list_1", updated_min: "2026-05-15T10:00:00.000Z"},
          "token"
        ) do
      {:ok,
       %{
         tasks: [
           Task.new!(%{
             task_id: "task_2",
             task_list_id: "list_1",
             title: "Write report",
             status: "completed",
             updated: "2026-05-15T10:30:00.000Z"
           }),
           Task.new!(%{
             task_id: "task_4",
             task_list_id: "list_1",
             title: "New task",
             status: "needsAction",
             updated: "2026-05-15T11:00:00.000Z"
           })
         ],
         next_page_token: "page_2"
       }}
    end

    # No changes after this checkpoint
    def list_tasks(
          %{task_list_id: "list_1", updated_min: "2026-05-16T12:00:00.000Z"},
          "token"
        ) do
      {:ok, %{tasks: []}}
    end

    # Empty task list
    def list_tasks(%{task_list_id: "empty_list"}, "token") do
      {:ok, %{tasks: []}}
    end
  end

  describe "poll/2 with no checkpoint" do
    test "initializes checkpoint without emitting signals" do
      config = %{task_list_id: @task_list_id}
      credentials = %{access_token: "token", google_tasks_client: FakeClient}

      assert {:ok, %{signals: [], checkpoint: checkpoint}} =
               TaskChangedPoller.poll(config, %{credentials: credentials, checkpoint: nil})

      assert checkpoint == "2026-05-15T12:00:00.000Z"
    end

    test "initializes checkpoint with empty string treated as nil" do
      config = %{task_list_id: @task_list_id}
      credentials = %{access_token: "token", google_tasks_client: FakeClient}

      assert {:ok, %{signals: []}} =
               TaskChangedPoller.poll(config, %{credentials: credentials, checkpoint: ""})
    end

    test "returns error when task list has no tasks with updated timestamps" do
      config = %{task_list_id: "empty_list"}
      credentials = %{access_token: "token", google_tasks_client: FakeClient}

      assert {:error, %Jido.Connect.Error.ProviderError{reason: :invalid_response}} =
               TaskChangedPoller.poll(config, %{credentials: credentials, checkpoint: nil})
    end
  end

  describe "poll/2 with existing checkpoint" do
    test "emits signals for changed tasks and advances checkpoint" do
      config = %{task_list_id: @task_list_id}
      credentials = %{access_token: "token", google_tasks_client: FakeClient}
      checkpoint = "2026-05-15T10:00:00.000Z"

      assert {:ok, %{signals: signals, checkpoint: new_checkpoint}} =
               TaskChangedPoller.poll(config, %{credentials: credentials, checkpoint: checkpoint})

      assert new_checkpoint == "2026-05-15T12:00:00.000Z"

      # 2 tasks on page 1 + 1 task on page 2
      assert length(signals) == 3

      signal_ids = Enum.map(signals, & &1.task_id) |> Enum.sort()
      assert signal_ids == ~w(task_1 task_2 task_4)
    end

    test "sets change_type to deleted for deleted tasks" do
      config = %{task_list_id: @task_list_id}
      credentials = %{access_token: "token", google_tasks_client: FakeClient}
      checkpoint = "2026-05-15T10:00:00.000Z"

      assert {:ok, %{signals: signals}} =
               TaskChangedPoller.poll(config, %{credentials: credentials, checkpoint: checkpoint})

      deleted_signal = Enum.find(signals, &(&1.task_id == "task_1"))
      assert deleted_signal.change_type == "deleted"
    end

    test "sets change_type to completed for completed tasks" do
      config = %{task_list_id: @task_list_id}
      credentials = %{access_token: "token", google_tasks_client: FakeClient}
      checkpoint = "2026-05-15T10:00:00.000Z"

      assert {:ok, %{signals: signals}} =
               TaskChangedPoller.poll(config, %{credentials: credentials, checkpoint: checkpoint})

      completed_signal = Enum.find(signals, &(&1.task_id == "task_2"))
      assert completed_signal.change_type == "completed"
    end

    test "sets change_type to updated for updated tasks" do
      config = %{task_list_id: @task_list_id}
      credentials = %{access_token: "token", google_tasks_client: FakeClient}
      checkpoint = "2026-05-15T10:00:00.000Z"

      assert {:ok, %{signals: signals}} =
               TaskChangedPoller.poll(config, %{credentials: credentials, checkpoint: checkpoint})

      updated_signal = Enum.find(signals, &(&1.task_id == "task_4"))
      assert updated_signal.change_type == "updated"
    end

    test "deduplicates signals with same task_id and updated" do
      config = %{task_list_id: @task_list_id}
      credentials = %{access_token: "token", google_tasks_client: FakeClient}
      checkpoint = "2026-05-15T10:00:00.000Z"

      assert {:ok, %{signals: signals}} =
               TaskChangedPoller.poll(config, %{credentials: credentials, checkpoint: checkpoint})

      keys = Enum.map(signals, &{&1.task_id, &1.updated})
      assert length(keys) == length(Enum.uniq(keys))
    end

    test "returns empty signals when no tasks changed" do
      config = %{task_list_id: @task_list_id}
      credentials = %{access_token: "token", google_tasks_client: FakeClient}
      checkpoint = "2026-05-16T12:00:00.000Z"

      assert {:ok, %{signals: [], checkpoint: ^checkpoint}} =
               TaskChangedPoller.poll(config, %{credentials: credentials, checkpoint: checkpoint})
    end
  end

  describe "signal shape" do
    test "each signal contains expected fields" do
      config = %{task_list_id: @task_list_id}
      credentials = %{access_token: "token", google_tasks_client: FakeClient}
      checkpoint = "2026-05-15T10:00:00.000Z"

      assert {:ok, %{signals: [signal | _]}} =
               TaskChangedPoller.poll(config, %{credentials: credentials, checkpoint: checkpoint})

      assert Map.has_key?(signal, :task_id)
      assert Map.has_key?(signal, :task_list_id)
      assert Map.has_key?(signal, :title)
      assert Map.has_key?(signal, :status)
      assert Map.has_key?(signal, :change_type)
      assert Map.has_key?(signal, :updated)
      assert Map.has_key?(signal, :task)
    end
  end
end
