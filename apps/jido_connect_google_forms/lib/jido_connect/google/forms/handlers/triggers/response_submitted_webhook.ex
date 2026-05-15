defmodule Jido.Connect.Google.Forms.Handlers.Triggers.ResponseSubmittedWebhook do
  @moduledoc false

  alias Jido.Connect.Google.Forms.Webhook

  defdelegate normalize_signal(delivery), to: Webhook
  defdelegate normalize_pubsub_push(payload), to: Webhook
end
