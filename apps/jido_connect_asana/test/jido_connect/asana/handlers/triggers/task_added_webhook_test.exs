defmodule Jido.Connect.Asana.Handlers.Triggers.TaskAddedWebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.Handlers.Triggers.TaskAddedWebhook

  describe "normalize_signal/1" do
    test "delegates to Webhook.normalize_event for task added" do
      delivery = fixture!("webhook_task_created.json")

      assert {:ok, signal} = TaskAddedWebhook.normalize_signal(delivery)
      assert signal.resource_gid == "998899"
      assert signal.resource_type == "task"
      assert signal.action == "added"
      assert signal.change_type == "created"
      assert signal.parent_gid == "445566"
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
