defmodule Jido.Connect.Asana.Handlers.Triggers.ProjectChangedWebhookTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Asana.Handlers.Triggers.ProjectChangedWebhook

  describe "normalize_signal/1" do
    test "delegates to Webhook.normalize_event for project changed" do
      delivery = fixture!("webhook_project_changed.json")

      assert {:ok, signal} = ProjectChangedWebhook.normalize_signal(delivery)
      assert signal.resource_gid == "445566"
      assert signal.resource_type == "project"
      assert signal.resource_name == "Website Redesign"
      assert signal.action == "changed"
      assert signal.change_type == "updated"
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
