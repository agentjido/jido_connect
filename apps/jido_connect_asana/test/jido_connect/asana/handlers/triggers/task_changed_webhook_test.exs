defmodule Jido.Connect.Asana.Handlers.Triggers.TaskChangedWebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.Handlers.Triggers.TaskChangedWebhook

  describe "normalize_signal/1" do
    test "delegates to Webhook.normalize_event for task changed" do
      delivery = fixture!("webhook_task_changed.json")

      assert {:ok, signal} = TaskChangedWebhook.normalize_signal(delivery)
      assert signal.resource_gid == "998877"
      assert signal.resource_type == "task"
      assert signal.action == "changed"
      assert signal.change_type == "updated"
      assert signal.parent_gid == "445566"
      assert signal.parent_type == "project"
      assert signal.user_gid == "123456"
      assert signal.user_name == "Alice Nakamura"
    end
  end

  defp fixture!(name) do
    Path.join([__DIR__, "..", "..", "..", "..", "fixtures", "asana", name])
    |> Path.expand()
    |> File.read!()
    |> Jason.decode!()
  end
end
