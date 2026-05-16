defmodule Jido.Connect.HubSpot.Handlers.Triggers.ContactChangedWebhook do
  @moduledoc false

  alias Jido.Connect.HubSpot.Webhook

  defdelegate normalize_signal(delivery), to: Webhook, as: :normalize_event
end
