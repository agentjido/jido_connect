defmodule Jido.Connect.Webhook do
  @moduledoc """
  Shared pure helpers for provider webhook verification and parsing.
  """

  alias Jido.Connect.{Error, Security}

  @spec header(map(), String.t()) :: term()
  def header(headers, key) when is_map(headers) and is_binary(key) do
    target = normalize_header_key(key)

    Enum.find_value(headers, fn
      {header_key, value} ->
        if normalize_header_key(header_key) == target, do: value
    end)
  end

  @spec verify_hmac_sha256(String.t(), String.t() | nil, String.t() | nil, keyword()) ::
          :ok | {:error, Error.AuthError.t()}
  def verify_hmac_sha256(body, signature, secret, opts \\ [])

  def verify_hmac_sha256(_body, _signature, secret, opts) when secret in [nil, ""] do
    {:error,
     Error.auth(Keyword.get(opts, :missing_secret_message, "Webhook secret is required"),
       reason: Keyword.get(opts, :missing_secret_reason, :missing_secret)
     )}
  end

  def verify_hmac_sha256(_body, signature, _secret, opts) when signature in [nil, ""] do
    {:error,
     Error.auth(Keyword.get(opts, :missing_signature_message, "Webhook signature is required"),
       reason: Keyword.get(opts, :missing_signature_reason, :missing_signature)
     )}
  end

  def verify_hmac_sha256(body, signature, secret, opts)
      when is_binary(body) and is_binary(signature) and is_binary(secret) do
    prefix = Keyword.get(opts, :prefix, "")

    with {:ok, expected} <- strip_prefix(signature, prefix) do
      actual = Security.hmac_sha256_hex(secret, body)

      if Security.secure_compare?(actual, expected) do
        :ok
      else
        invalid_signature(opts)
      end
    else
      :error -> invalid_signature(opts)
    end
  end

  @spec decode_json(String.t(), keyword()) :: {:ok, map() | list()} | {:error, Error.error()}
  def decode_json(body, opts) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, payload} when is_map(payload) or is_list(payload) ->
        {:ok, payload}

      {:ok, _payload} ->
        invalid_payload(opts)

      {:error, error} ->
        invalid_payload(opts, %{error: error})
    end
  end

  defp invalid_payload(opts, details \\ %{}) do
    {:error,
     Error.provider(Keyword.get(opts, :message, "Webhook body is invalid JSON"),
       provider: Keyword.fetch!(opts, :provider),
       reason: Keyword.get(opts, :reason, :invalid_payload),
       details: details
     )}
  end

  @spec duplicate?(term(), Enumerable.t()) :: boolean()
  def duplicate?(delivery_id, seen_delivery_ids), do: delivery_id in seen_delivery_ids

  defp strip_prefix(signature, ""), do: {:ok, signature}

  defp strip_prefix(signature, prefix) do
    case signature do
      ^prefix <> value -> {:ok, value}
      _other -> :error
    end
  end

  defp invalid_signature(opts) do
    {:error,
     Error.auth(Keyword.get(opts, :invalid_signature_message, "Webhook signature is invalid"),
       reason: Keyword.get(opts, :invalid_signature_reason, :invalid_signature)
     )}
  end

  defp normalize_header_key(key) do
    key
    |> to_string()
    |> String.downcase()
    |> String.replace("_", "-")
  end
end
