defmodule Jido.Connect.GitHub.Webhook do
  @moduledoc """
  Pure helpers for GitHub webhook verification and event normalization.
  """

  alias Jido.Connect.GitHub.Webhook.{Normalizer, Verification}

  @doc "Normalizes request headers into a lower-case map."
  defdelegate parse_headers(headers), to: Verification

  @doc "Verifies a GitHub webhook signature."
  defdelegate verify_signature(body, signature, secret), to: Verification

  @doc "Verifies and decodes a GitHub webhook request."
  defdelegate verify_request(body, headers, secret), to: Verification

  @doc "Verifies a GitHub webhook and returns a normalized delivery."
  defdelegate verify_delivery(body, headers, secret, opts \\ []), to: Verification

  @doc "Checks whether a delivery identifier was already processed."
  defdelegate duplicate?(delivery_id, seen_delivery_ids), to: Verification

  @doc "Normalizes a verified GitHub delivery into a signal map."
  defdelegate normalize_signal(delivery), to: Normalizer

  @doc "Normalizes a GitHub event and payload into a signal map."
  defdelegate normalize_signal(event, payload), to: Normalizer
end
