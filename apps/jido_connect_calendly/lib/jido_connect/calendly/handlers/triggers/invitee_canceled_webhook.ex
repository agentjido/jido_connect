defmodule Jido.Connect.Calendly.Handlers.Triggers.InviteeCanceledWebhook do
  @moduledoc false

  alias Jido.Connect.Calendly.Webhook

  def run(payload, _runtime) do
    Webhook.normalize_event(payload)
  end
end
