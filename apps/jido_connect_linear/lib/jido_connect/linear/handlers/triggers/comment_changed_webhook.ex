defmodule Jido.Connect.Linear.Handlers.Triggers.CommentChangedWebhook do
  @moduledoc false

  alias Jido.Connect.Linear.Webhook

  def run(payload, _runtime) do
    Webhook.normalize_event(payload)
  end
end
