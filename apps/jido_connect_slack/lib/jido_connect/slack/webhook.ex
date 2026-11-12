defmodule Jido.Connect.Slack.Webhook do
  @moduledoc """
  Pure helpers for Slack signed request verification and event normalization.
  """

  alias Jido.Connect.Slack.Webhook.{Normalizer, Verification}

  @doc "Normalizes request headers into a lower-case map."
  defdelegate parse_headers(headers), to: Verification

  @doc "Verifies a Slack request signature and timestamp."
  defdelegate verify_signature(body, headers, signing_secret, opts \\ []), to: Verification

  @doc "Verifies and decodes a Slack request."
  defdelegate verify_request(body, headers, signing_secret, opts \\ []), to: Verification

  @doc "Verifies a Slack request and returns a normalized delivery."
  defdelegate verify_delivery(body, headers, signing_secret, opts \\ []), to: Verification

  def url_verification_challenge(%{"type" => "url_verification", "challenge" => challenge})
      when is_binary(challenge) do
    {:ok, challenge}
  end

  def url_verification_challenge(_payload) do
    {:error,
     Jido.Connect.Error.provider("Slack payload is not a URL verification challenge",
       provider: :slack,
       reason: :not_url_verification
     )}
  end

  @doc "Normalizes a verified Slack delivery into a signal map."
  defdelegate normalize_signal(delivery), to: Normalizer

  @doc "Normalizes a Slack event and payload into a signal map."
  defdelegate normalize_signal(event, payload), to: Normalizer

  @doc "Normalizes a Slack event payload."
  defdelegate normalize_event(payload), to: Normalizer
end
