defmodule Jido.Connect.ProviderResponse do
  @moduledoc """
  Provider HTTP response envelope normalized by connector packages.

  This struct is for observability, error reporting, retries, and host UIs. It
  is not a provider domain object. Provider clients still own success payload
  normalization into action outputs or trigger signals.
  """

  alias Jido.Connect.Sanitizer

  @schema Zoi.struct(
            __MODULE__,
            %{
              provider: Zoi.atom(),
              operation: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              status: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              reason: Zoi.any() |> Zoi.nullish() |> Zoi.optional(),
              request_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              retry_after: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              delivery:
                Zoi.enum([:not_sent, :rejected, :response_received, :sent_outcome_unknown])
                |> Zoi.default(:sent_outcome_unknown),
              action_risk: Zoi.atom() |> Zoi.nullish() |> Zoi.optional(),
              mutation?: Zoi.boolean() |> Zoi.default(false),
              provider_idempotency?: Zoi.boolean() |> Zoi.default(false),
              headers: Zoi.map() |> Zoi.default(%{}),
              body: Zoi.any() |> Zoi.nullish() |> Zoi.optional(),
              metadata: Zoi.map() |> Zoi.default(%{})
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  def schema, do: @schema
  def new!(attrs), do: Zoi.parse!(@schema, attrs)
  def new(attrs), do: Zoi.parse(@schema, attrs)

  @doc "Normalizes a Req-style response or transport error."
  @spec from_result(atom(), term(), keyword()) :: {:ok, t()} | {:error, term()}
  def from_result(provider, result, opts \\ []) when is_atom(provider) do
    result
    |> attrs(provider, opts)
    |> new()
  end

  @doc "Bang variant of `from_result/3`."
  @spec from_result!(atom(), term(), keyword()) :: t()
  def from_result!(provider, result, opts \\ []) when is_atom(provider) do
    result
    |> attrs(provider, opts)
    |> new!()
  end

  @doc "Returns true for 2xx provider responses."
  @spec success?(t()) :: boolean()
  def success?(%__MODULE__{status: status}) when status in 200..299, do: true
  def success?(%__MODULE__{}), do: false

  @doc "Returns true when the response represents a retryable provider failure."
  @spec retryable?(t()) :: boolean()
  def retryable?(%__MODULE__{delivery: :not_sent}), do: true

  def retryable?(%__MODULE__{
        delivery: :sent_outcome_unknown,
        mutation?: true,
        provider_idempotency?: false
      }),
      do: false

  def retryable?(%__MODULE__{
        status: status,
        mutation?: true,
        provider_idempotency?: false
      })
      when status in 500..599,
      do: false

  def retryable?(%__MODULE__{status: status}) when status == 429 or status in 500..599, do: true
  def retryable?(%__MODULE__{reason: reason}) when reason in [:request_error, :timeout], do: true
  def retryable?(%__MODULE__{}), do: false

  @doc "Returns stable retry guidance for this provider outcome."
  @spec retry_guidance(t()) ::
          :safe_to_retry | :retry_with_idempotency | :do_not_retry | :not_applicable
  def retry_guidance(%__MODULE__{} = response) do
    cond do
      success?(response) ->
        :not_applicable

      response.delivery == :not_sent ->
        :safe_to_retry

      response.mutation? and response.provider_idempotency? and retryable?(response) ->
        :retry_with_idempotency

      retryable?(response) ->
        :safe_to_retry

      true ->
        :do_not_retry
    end
  end

  @doc "Returns a transport-safe map with sensitive fields redacted."
  @spec to_public_map(t()) :: map()
  def to_public_map(%__MODULE__{} = response) do
    %{
      provider: response.provider,
      operation: response.operation,
      status: response.status,
      reason: response.reason,
      request_id: response.request_id,
      retry_after: response.retry_after,
      delivery: response.delivery,
      action_risk: response.action_risk,
      retryable?: retryable?(response),
      retry_guidance: retry_guidance(response),
      headers: Sanitizer.sanitize(response.headers, :transport),
      body_summary: Sanitizer.provider_body_summary(response.body, :transport),
      metadata: Sanitizer.sanitize(response.metadata, :transport)
    }
  end

  defp attrs({:ok, %{status: status} = response}, provider, opts) do
    headers = normalize_headers(Map.get(response, :headers, %{}))

    %{
      provider: provider,
      operation: operation(opts),
      status: status,
      reason: Keyword.get(opts, :reason),
      request_id: request_id(headers),
      retry_after: retry_after(headers, opts),
      delivery: delivery_for_status(status, opts),
      action_risk: action_risk(opts),
      mutation?: mutation?(opts),
      provider_idempotency?: Keyword.get(opts, :provider_idempotency?, false),
      headers: headers,
      body: Map.get(response, :body),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  defp attrs({:error, reason}, provider, opts) do
    %{
      provider: provider,
      operation: operation(opts),
      reason: transport_reason(reason),
      delivery: delivery_for_error(reason, opts),
      action_risk: action_risk(opts),
      mutation?: mutation?(opts),
      provider_idempotency?: Keyword.get(opts, :provider_idempotency?, false),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  defp attrs(response, provider, opts) do
    %{
      provider: provider,
      operation: operation(opts),
      reason: Keyword.get(opts, :reason, :unexpected_response),
      delivery: Keyword.get(opts, :delivery, :response_received),
      action_risk: action_risk(opts),
      mutation?: mutation?(opts),
      provider_idempotency?: Keyword.get(opts, :provider_idempotency?, false),
      body: response,
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  defp operation(opts) do
    case Keyword.get(opts, :operation) do
      nil -> nil
      operation -> to_string(operation)
    end
  end

  defp normalize_headers(headers) when is_map(headers) do
    Map.new(headers, fn {key, value} ->
      {normalize_header_key(key), normalize_header_value(value)}
    end)
  end

  defp normalize_headers(headers) when is_list(headers) do
    Map.new(headers, fn {key, value} ->
      {normalize_header_key(key), normalize_header_value(value)}
    end)
  end

  defp normalize_headers(_headers), do: %{}

  defp normalize_header_key(key) do
    key
    |> to_string()
    |> String.downcase()
  end

  defp normalize_header_value([value | _rest]), do: to_string(value)
  defp normalize_header_value(value), do: to_string(value)

  defp request_id(headers) do
    Enum.find_value(
      ["x-request-id", "x-github-request-id", "x-slack-req-id"],
      &Map.get(headers, &1)
    )
  end

  defp retry_after(headers, opts) do
    Keyword.get(opts, :retry_after) || parse_integer(Map.get(headers, "retry-after"))
  end

  defp delivery_for_status(status, opts) do
    Keyword.get_lazy(opts, :delivery, fn ->
      if status in 200..299, do: :response_received, else: :rejected
    end)
  end

  defp delivery_for_error(reason, opts) do
    Keyword.get_lazy(opts, :delivery, fn ->
      case transport_reason(reason) do
        value when value in [:econnrefused, :nxdomain, :enetunreach, :ehostunreach] ->
          :not_sent

        _reason ->
          :sent_outcome_unknown
      end
    end)
  end

  defp transport_reason(%{reason: reason}), do: reason
  defp transport_reason(reason), do: reason

  defp action_risk(opts), do: Keyword.get(opts, :action_risk, Keyword.get(opts, :risk))

  defp mutation?(opts) do
    case Keyword.fetch(opts, :mutation?) do
      {:ok, mutation?} -> mutation?
      :error -> action_risk(opts) not in [nil, :read, :metadata]
    end
  end

  defp parse_integer(nil), do: nil

  defp parse_integer(value) do
    case Integer.parse(to_string(value)) do
      {integer, ""} -> integer
      _other -> nil
    end
  end
end

defimpl Inspect, for: Jido.Connect.ProviderResponse do
  import Inspect.Algebra

  def inspect(response, opts) do
    response
    |> Jido.Connect.ProviderResponse.to_public_map()
    |> to_doc(opts)
    |> then(&concat(["#Jido.Connect.ProviderResponse<", &1, ">"]))
  end
end
