defmodule Jido.Connect.InboundWebhook.Handlers.Triggers.InboundDeliveryWebhook do
  @moduledoc false

  alias Jido.Connect.InboundWebhook.Normalizer

  defdelegate normalize_signal(delivery), to: Normalizer
  defdelegate extract_headers(delivery), to: Normalizer
  defdelegate extract_query(delivery), to: Normalizer
  defdelegate dedupe_key(delivery), to: Normalizer
  defdelegate delivery_summary(delivery), to: Normalizer
end
