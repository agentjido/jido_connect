defmodule Jido.Connect.Tempo.Client.Response do
  @moduledoc """
  Tempo REST v4 success and error response handling.

  Every failure becomes a `Jido.Connect.Error.ProviderError` with
  `provider: :tempo`. HTTP failures carry the status, a reason derived from
  it and `details.retry_after` from an integer `Retry-After` header:

  | Status | Reason |
  | --- | --- |
  | 3xx | `:redirect_not_followed` |
  | 400 | `:bad_request` |
  | 401 | `:unauthorized` |
  | 403 | `:forbidden` |
  | 404 | `:not_found` |
  | 429 | `:rate_limited` |
  | 5xx | `:server_error` |
  | other | `:http_error` |

  The `:reasons` option of `handle/2` gives a failure of a given status
  whose Tempo error text contains a given text its own reason instead of
  the status reason. With `mutation?: true`, for a request that Tempo does
  not deduplicate, every error carries `mutation?: true` and
  `provider_idempotency?: false`, and a 3xx, a 5xx and a malformed 2xx get
  `delivery: :sent_outcome_unknown`.

  `details.message` is Tempo's error text from the recorded body form
  `{"errors": [{"message": ...}]}`, else the top-level `message` of the
  token endpoint's form `{"message": ..., "status": ...}`; the `:redact`
  option of `handle/2` applies to both. Tempo answers 401, and 404 for an
  unknown route, without a JSON body; those keep only the body size. A 2xx
  response without a JSON object or list is `:invalid_response`; a
  transport failure, such as a timeout, is `:request_error` with the reason
  code in `details.reason`. Raw bodies are reduced to a value-free summary.

  Every Tempo request decodes JSON in its own response step, attached by
  `attach_json_decoder/1` when the request is built, instead of Req's
  `decode_body`. A body that does not decode stays raw, so an error response
  whose JSON body is malformed keeps its status, reason and `retry_after`,
  with only the body size.
  """

  alias Jido.Connect.Error
  alias Jido.Connect.Provider.Transport

  @message "Tempo API request failed"
  @json_step :tempo_decode_json
  @invalid_json :tempo_invalid_json
  @mutation [mutation?: true, provider_idempotency?: false]

  @doc """
  Turns Req's body decoding off and appends Tempo's JSON decoding step.

  The step decodes a non-empty `application/json` or `+json` body. Since it
  is attached when the request is built, it runs before any response step
  an adapter appends while the request runs, such as the live smoke
  recorder's, so that step sees the decoded body. A body that does not
  decode stays raw and is marked for `handle/2`; Req's own decode error
  would drop the status and the headers.
  """
  @spec attach_json_decoder(Req.Request.t()) :: Req.Request.t()
  def attach_json_decoder(%Req.Request{} = request) do
    request
    |> Req.merge(decode_body: false)
    |> Req.Request.append_response_steps([{@json_step, &decode_json/1}])
  end

  @doc """
  Returns the decoded JSON body of a successful response or a normalized error.

  Expects a response of a request prepared by `attach_json_decoder/1`.
  Options: `:message`, the error message; `:redact`, values replaced by
  `[redacted]` in Tempo's error text before the error is built and that
  text is cut to 256 bytes; `:delivery`, which overrides the delivery
  inferred for a transport failure, such as `:not_sent` for a request that
  was stopped before it was sent; `:reasons`, a list of
  `{status, text, reason}` that gives an HTTP failure with that status and
  Tempo error text containing `text` that reason instead of the status
  reason; and `:mutation?`.

  With `mutation?: true` the request is a mutation that Tempo does not
  deduplicate: every error carries `mutation?: true` and
  `provider_idempotency?: false`, and a 3xx, a 5xx and a malformed 2xx get
  `delivery: :sent_outcome_unknown`, since Tempo may have applied the
  mutation. A transport failure keeps its inferred delivery, which is
  `:sent_outcome_unknown` unless the reason shows that nothing was sent.
  """
  @spec handle(term(), keyword()) :: {:ok, map() | list()} | {:error, Error.ProviderError.t()}
  def handle(response, opts \\ [])

  def handle({:ok, %{status: status, body: body}}, _opts)
      when status in 200..299 and (is_map(body) or is_list(body)) do
    {:ok, body}
  end

  def handle({:ok, %{status: status, body: body} = response}, opts) when status in 200..299 do
    message =
      if invalid_json?(response),
        do: "Tempo API response was not valid JSON",
        else: "Tempo API response was not JSON"

    invalid_response(
      Keyword.get(opts, :message, message),
      body,
      [status: status] ++ Keyword.take(opts, [:mutation?])
    )
  end

  # An error body that is not valid JSON stays raw: the error keeps the
  # status, Retry-After and the body size.
  def handle({:ok, %{status: status} = response}, opts) when is_integer(status) do
    http_error(response, opts)
  end

  def handle(response, opts) do
    Transport.provider_error(
      response,
      [provider: :tempo, message: Keyword.get(opts, :message, @message)] ++
        Keyword.take(opts, [:delivery]) ++ mutation(opts, nil)
    )
  end

  @doc """
  Returns a provider error for a successful response whose payload is malformed.

  With `mutation?: true` its delivery is `:sent_outcome_unknown`, else
  `:response_received`.
  """
  @spec invalid_response(String.t(), term(), keyword()) :: {:error, Error.ProviderError.t()}
  def invalid_response(message, body, opts \\ []) do
    mutation? = Keyword.get(opts, :mutation?, false)

    {:error,
     Error.provider(message,
       provider: :tempo,
       reason: Keyword.get(opts, :reason, :invalid_response),
       status: Keyword.get(opts, :status),
       delivery: if(mutation?, do: :sent_outcome_unknown, else: :response_received),
       mutation?: mutation?,
       provider_idempotency?: false,
       details: Map.merge(%{body: body}, Keyword.get(opts, :details, %{}))
     )}
  end

  defp http_error(%{status: status, body: body} = response, opts) do
    message = error_message(body)

    error_opts =
      [
        provider: :tempo,
        message: Keyword.get(opts, :message, @message),
        reason: reason(status, message, Keyword.get(opts, :reasons, []))
      ] ++ mutation(opts, status)

    error_opts =
      case message do
        nil -> error_opts
        message -> Keyword.put(error_opts, :detail_message, redact(message, opts))
      end

    Transport.provider_error({:ok, response}, error_opts)
  end

  defp mutation(opts, status) do
    cond do
      not Keyword.get(opts, :mutation?, false) -> []
      status in 300..399 or status in 500..599 -> @mutation ++ [delivery: :sent_outcome_unknown]
      true -> @mutation
    end
  end

  # A configured reason for this status and Tempo text, else the status reason.
  defp reason(status, message, reasons) do
    Enum.find_value(reasons, reason(status), fn {rule_status, text, reason} ->
      if status == rule_status and is_binary(message) and String.contains?(message, text),
        do: reason
    end)
  end

  defp decode_json({request, %Req.Response{body: body} = response})
       when is_binary(body) and body != "" do
    if json?(response) do
      case Jason.decode(body) do
        {:ok, decoded} -> {request, %{response | body: decoded}}
        {:error, _error} -> {request, Req.Response.put_private(response, @invalid_json, true)}
      end
    else
      {request, response}
    end
  end

  defp decode_json(request_response), do: request_response

  defp invalid_json?(%Req.Response{} = response),
    do: Req.Response.get_private(response, @invalid_json, false)

  defp invalid_json?(_response), do: false

  defp json?(%Req.Response{} = response) do
    response
    |> Req.Response.get_header("content-type")
    |> Enum.any?(fn value ->
      media_type = value |> String.split(";") |> hd() |> String.trim() |> String.downcase()
      media_type == "application/json" or String.ends_with?(media_type, "+json")
    end)
  end

  defp reason(status) when status in 300..399, do: :redirect_not_followed
  defp reason(400), do: :bad_request
  defp reason(401), do: :unauthorized
  defp reason(403), do: :forbidden
  defp reason(404), do: :not_found
  defp reason(429), do: :rate_limited
  defp reason(status) when status in 500..599, do: :server_error
  defp reason(_status), do: :http_error

  # Tempo's `errors` messages, else the top-level `message`. Both are taken
  # here and redacted, so the core's own fallback to the top-level `message`
  # can only add its generic text.
  defp error_message(%{"errors" => [_ | _] = errors} = body) do
    case for(%{"message" => message} when is_binary(message) <- errors, do: message) do
      [] -> top_level_message(body)
      messages -> Enum.join(messages, "; ")
    end
  end

  defp error_message(body), do: top_level_message(body)

  defp top_level_message(%{"message" => message}) when is_binary(message), do: message
  defp top_level_message(_body), do: nil

  defp redact(message, opts) do
    opts
    |> Keyword.get(:redact, [])
    |> Enum.reject(&(&1 == ""))
    |> Enum.reduce(message, &String.replace(&2, &1, "[redacted]"))
  end
end
