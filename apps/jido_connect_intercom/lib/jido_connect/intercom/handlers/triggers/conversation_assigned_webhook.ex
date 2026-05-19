defmodule Jido.Connect.Intercom.Handlers.Triggers.ConversationAssignedWebhook do
  @moduledoc false

  alias Jido.Connect.Intercom.Webhook

  defdelegate normalize_signal(delivery), to: Webhook, as: :normalize_event
end
