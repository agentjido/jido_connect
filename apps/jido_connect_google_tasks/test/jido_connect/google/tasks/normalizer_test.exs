defmodule Jido.Connect.Google.Tasks.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Tasks.Normalizer
  alias Jido.Connect.Google.Tasks.{Task, TaskList}

  # --- Task list normalization ---

  test "normalizes a full task list payload" do
    payload = %{
      "id" => "MDAxNjUwMjY0MzQ1NjM0NzY3Mjo3Njc0MzI2NDpx",
      "etag" => "\"L11-Pmu_bA\"",
      "title" => "My Tasks",
      "updated" => "2026-05-14T10:00:00.000Z",
      "selfLink" => "https://www.googleapis.com/tasks/v1/users/@me/lists/MDAxNjU"
    }

    assert {:ok, %TaskList{} = task_list} = Normalizer.task_list(payload)
    assert task_list.task_list_id == "MDAxNjUwMjY0MzQ1NjM0NzY3Mjo3Njc0MzI2NDpx"
    assert task_list.etag == "\"L11-Pmu_bA\""
    assert task_list.title == "My Tasks"
    assert task_list.updated == "2026-05-14T10:00:00.000Z"

    assert task_list.self_link ==
             "https://www.googleapis.com/tasks/v1/users/@me/lists/MDAxNjU"
  end

  test "normalizes a minimal task list payload" do
    payload = %{"id" => "list_1"}

    assert {:ok, %TaskList{} = task_list} = Normalizer.task_list(payload)
    assert task_list.task_list_id == "list_1"
    assert task_list.title == nil
    assert task_list.metadata == %{}
  end

  test "rejects a non-map payload" do
    assert {:error, :invalid_task_list_payload} = Normalizer.task_list("not a map")
  end

  test "rejects a payload missing id" do
    payload = %{"title" => "No ID"}

    assert {:error, _error} = Normalizer.task_list(payload)
  end

  # --- Task normalization ---

  test "normalizes a full task payload" do
    payload = %{
      "id" => "task_abc123",
      "etag" => "\"etag456\"",
      "title" => "Buy groceries",
      "updated" => "2026-05-12T09:30:00.000Z",
      "selfLink" => "https://www.googleapis.com/tasks/v1/lists/list_xyz/tasks/task_abc123",
      "parent" => "",
      "position" => "00000000000000000000",
      "notes" => "Milk, eggs, bread, and coffee.",
      "status" => "needsAction",
      "due" => "2026-05-20T00:00:00.000Z",
      "completed" => "",
      "deleted" => false,
      "hidden" => false,
      "links" => [
        %{
          "type" => "text/html",
          "description" => "Shopping list",
          "link" => "https://example.com/shopping-list"
        }
      ],
      "webViewLink" => "https://tasks.google.com/task/task_abc123"
    }

    assert {:ok, %Task{} = task} = Normalizer.task(payload)
    assert task.task_id == "task_abc123"
    assert task.title == "Buy groceries"
    assert task.status == "needsAction"
    assert task.due == "2026-05-20T00:00:00.000Z"
    assert task.notes == "Milk, eggs, bread, and coffee."
    assert task.etag == "\"etag456\""
    assert task.updated == "2026-05-12T09:30:00.000Z"
    assert task.parent == nil
    assert task.position == "00000000000000000000"
    assert task.completed == nil
    assert task.deleted? == false
    assert task.hidden? == false

    assert [%{type: "text/html", description: "Shopping list"}] = task.links

    assert task.web_view_link == "https://tasks.google.com/task/task_abc123"
  end

  test "normalizes a minimal task payload" do
    payload = %{"id" => "task_min"}

    assert {:ok, %Task{} = task} = Normalizer.task(payload)
    assert task.task_id == "task_min"
    assert task.title == nil
    assert task.status == nil
    assert task.deleted? == false
    assert task.hidden? == false
    assert task.links == []
    assert task.metadata == %{}
  end

  test "normalizes task payload with task_list_id context" do
    payload = %{"id" => "task_1", "task_list_id" => "list_1"}

    assert {:ok, %Task{} = task} = Normalizer.task(payload)
    assert task.task_id == "task_1"
    assert task.task_list_id == "list_1"
  end

  test "rejects a non-map task payload" do
    assert {:error, :invalid_task_payload} = Normalizer.task("not a map")
  end

  test "rejects a task payload missing id" do
    payload = %{"title" => "No ID"}

    assert {:error, _error} = Normalizer.task(payload)
  end

  test "handles empty links array" do
    payload = %{"id" => "task_links", "links" => []}

    assert {:ok, %Task{} = task} = Normalizer.task(payload)
    assert task.links == []
  end

  test "handles nil links" do
    payload = %{"id" => "task_nil_links", "links" => nil}

    assert {:ok, %Task{} = task} = Normalizer.task(payload)
    assert task.links == []
  end

  test "handles boolean deleted and hidden fields" do
    payload = %{"id" => "task_bool", "deleted" => true, "hidden" => true}

    assert {:ok, %Task{} = task} = Normalizer.task(payload)
    assert task.deleted? == true
    assert task.hidden? == true
  end
end
