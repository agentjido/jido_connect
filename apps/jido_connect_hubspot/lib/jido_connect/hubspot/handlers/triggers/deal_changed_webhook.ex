defmodule Jido.Connect.HubSpot.Handlers.Triggers.DealChangedWebhook do
  @moduledoc false

  alias Jido.Connect.HubSpot.Webhook

  defdelegate normalize_signal(delivery), to: Webhook, as: :normalize_event
end
