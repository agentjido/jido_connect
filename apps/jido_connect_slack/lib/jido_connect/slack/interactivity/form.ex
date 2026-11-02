defmodule Jido.Connect.Slack.Interactivity.Form do
  @moduledoc false

  alias Jido.Connect.Error

  @spec decode_payload(binary()) :: {:ok, map()} | {:error, Error.ProviderError.t()}
  def decode_payload(body) when is_binary(body) do
    with {:ok, json} <- payload_field(body),
         {:ok, payload} <- decode_json(json) do
      check_type(payload)
    end
  end

  defp payload_field(body) do
    body
    |> URI.query_decoder(:www_form)
    |> Enum.flat_map(fn
      {"payload", value} -> [value]
      {_key, _value} -> []
    end)
    |> case do
      [json] ->
        {:ok, json}

      [] ->
        form_error("Slack interactivity body has no payload field", :missing_payload)

      [_first, _second | _rest] ->
        form_error("Slack interactivity body has more than one payload field", :duplicate_payload)
    end
  end

  # Jason.DecodeError carries the whole input, so its details stay out of the error.
  defp decode_json(json) do
    case Jason.decode(json) do
      {:ok, %{} = payload} ->
        {:ok, payload}

      {:ok, _other} ->
        form_error("Slack interactivity payload must be a JSON object", :invalid_payload)

      {:error, %Jason.DecodeError{}} ->
        form_error("Slack interactivity payload is invalid JSON", :invalid_payload)
    end
  end

  defp check_type(%{"type" => type} = payload) when is_binary(type) or is_nil(type),
    do: {:ok, payload}

  defp check_type(%{"type" => _type}),
    do: form_error("Slack interactivity payload type must be a string", :invalid_payload)

  defp check_type(payload), do: {:ok, payload}

  defp form_error(message, reason) do
    {:error, Error.provider(message, provider: :slack, reason: reason)}
  end
end
