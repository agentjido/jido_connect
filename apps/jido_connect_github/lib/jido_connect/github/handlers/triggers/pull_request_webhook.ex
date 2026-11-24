defmodule Jido.Connect.GitHub.Handlers.Triggers.PullRequestWebhook do
  @moduledoc "Builds pull request Signal data from a verified GitHub delivery."

  alias Jido.Connect.{Error, WebhookDelivery}

  def run(
        %WebhookDelivery{
          provider: :github,
          event: "pull_request",
          signature_state: :verified,
          duplicate?: false,
          delivery_id: delivery_id,
          normalized_signal: %{repo: repo, pull_request_number: number, github_action: action}
        },
        _runtime
      )
      when is_binary(repo) and repo != "" and is_integer(number) and number > 0 and
             is_binary(action) and is_binary(delivery_id) and delivery_id != "" do
    {:ok, %{repo: repo, pull_number: number, action: action, delivery_id: delivery_id}}
  end

  def run(%WebhookDelivery{provider: :github, signature_state: :verified, duplicate?: true}, _) do
    {:error, Error.validation("GitHub delivery was already seen", reason: :duplicate_delivery)}
  end

  def run(_delivery, _runtime) do
    {:error,
     Error.validation("Expected a verified GitHub pull request delivery",
       reason: :invalid_webhook_delivery
     )}
  end
end
