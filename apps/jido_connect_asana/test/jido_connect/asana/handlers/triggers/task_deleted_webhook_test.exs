defmodule Jido.Connect.Asana.Handlers.Triggers.TaskDeletedWebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.Handlers.Triggers.TaskDeletedWebhook

  describe "normalize_signal/1" do
    test "delegates to Webhook.normalize_event for task deleted" do
      delivery = fixture!("webhook_task_deleted.json")

      assert {:ok, signal} = TaskDeletedWebhook.normalize_signal(delivery)
      assert signal.resource_gid == "998877"
      assert signal.resource_type == "task"
      assert signal.action == "deleted"
      assert signal.change_type == "deleted"
      assert signal.user_gid == "123456"
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "..", "fixtures", "asana", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
