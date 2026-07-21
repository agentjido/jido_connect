defmodule Jido.Connect.Zendesk.Handlers.Triggers.CommentChangedWebhook do
  @moduledoc false

  alias Jido.Connect.Zendesk.Webhook

  defdelegate normalize_signal(delivery), to: Webhook, as: :normalize_event
end
