defmodule Jido.Connect.Jira.Handlers.Triggers.CommentChangedWebhook do
  @moduledoc false

  alias Jido.Connect.Jira.Webhook

  defdelegate normalize_signal(delivery), to: Webhook, as: :normalize_event
end
