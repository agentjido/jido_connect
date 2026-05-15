defmodule Jido.Connect.Google.Tasks.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Tasks.Normalizer
  alias Jido.Connect.Google.Tasks.TaskList

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
end
