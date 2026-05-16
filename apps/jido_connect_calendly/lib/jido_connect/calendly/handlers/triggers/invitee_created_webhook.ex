defmodule Jido.Connect.Calendly.Handlers.Triggers.InviteeCreatedWebhook do
  @moduledoc false

  alias Jido.Connect.Calendly.Webhook

  def run(payload, _runtime) do
    Webhook.normalize_event(payload)
  end
end
