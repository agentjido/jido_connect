defmodule Jido.Connect.Examples.StartHere.WebhookHost do
  @moduledoc "Verifies one GitHub webhook request and delivers its Signal to the Agent."

  alias Jido.Connect.GitHub.Sensors.PullRequestWebhook
  alias Jido.Connect.GitHub.Webhook
  alias Jido.Connect.Plugin
  alias Jido.Connect.Examples.StartHere.{GitHubWebhook, Host}

  def receive_delivery(server, body, headers, secret, context, seen_delivery_ids \\ []) do
    with {:ok, trigger} <- Plugin.trigger(GitHubWebhook, :source, PullRequestWebhook.trigger_id()),
         {:ok, delivery} <-
           Webhook.verify_delivery(body, headers, secret, seen_delivery_ids: seen_delivery_ids),
         {:ok, data} <- trigger.handler.run(delivery, %{}),
         {:ok, signal} <-
           Jido.Signal.new(trigger.id, data, source: PullRequestWebhook.signal_source()) do
      Host.call(server, signal, %{connect: %{source: context}})
    end
  end
end
