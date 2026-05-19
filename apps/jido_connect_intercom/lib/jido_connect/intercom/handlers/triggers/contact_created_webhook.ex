defmodule Jido.Connect.Intercom.Handlers.Triggers.ContactCreatedWebhook do
  @moduledoc false

  alias Jido.Connect.Intercom.Webhook

  defdelegate normalize_signal(delivery), to: Webhook, as: :normalize_event
end
