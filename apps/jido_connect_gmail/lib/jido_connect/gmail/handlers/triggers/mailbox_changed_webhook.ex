defmodule Jido.Connect.Gmail.Handlers.Triggers.MailboxChangedWebhook do
  @moduledoc false

  alias Jido.Connect.Gmail.Webhook

  defdelegate normalize_signal(delivery), to: Webhook
  defdelegate normalize_pubsub_push(payload), to: Webhook
end
