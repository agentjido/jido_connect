defmodule Jido.Connect.WebhookDelivery do
  @moduledoc """
  Provider-neutral webhook delivery envelope.

  Provider packages verify signatures and decode provider payloads, then
  normalize into this struct. Hosts can use it for dedupe, audit, delivery
  consoles, and turning webhook payloads into the same signal shape as poll
  triggers.
  """

  alias Jido.Connect.Sanitizer

  @signature_states [:unverified, :verified, :invalid, :missing]

  @schema Zoi.struct(
            __MODULE__,
            %{
              provider: Zoi.atom(),
              event: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              delivery_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              received_at: Zoi.datetime(),
              signature_state: Zoi.enum(@signature_states) |> Zoi.default(:unverified),
              duplicate?: Zoi.boolean() |> Zoi.default(false),
              source: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              headers: Zoi.map() |> Zoi.default(%{}),
              payload: Zoi.any() |> Zoi.nullish() |> Zoi.optional(),
              normalized_signal: Zoi.any() |> Zoi.nullish() |> Zoi.optional(),
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

  @doc "Builds a verified webhook delivery."
  @spec verified(atom(), map() | keyword()) :: {:ok, t()} | {:error, term()}
  def verified(provider, attrs) when is_atom(provider) do
    attrs
    |> attrs_map()
    |> Map.merge(%{
      provider: provider,
      signature_state: :verified,
      received_at: Map.get(attrs_map(attrs), :received_at, DateTime.utc_now())
    })
    |> new()
  end

  @doc "Bang variant of `verified/2`."
  @spec verified!(atom(), map() | keyword()) :: t()
  def verified!(provider, attrs) when is_atom(provider) do
    attrs
    |> attrs_map()
    |> Map.merge(%{
      provider: provider,
      signature_state: :verified,
      received_at: Map.get(attrs_map(attrs), :received_at, DateTime.utc_now())
    })
    |> new!()
  end

  @doc "Marks a delivery as duplicate or not duplicate."
  @spec mark_duplicate(t(), boolean()) :: t()
  def mark_duplicate(%__MODULE__{} = delivery, duplicate? \\ true) when is_boolean(duplicate?) do
    %{delivery | duplicate?: duplicate?}
  end

  @doc "Attaches a normalized signal payload to the delivery."
  @spec put_signal(t(), term()) :: t()
  def put_signal(%__MODULE__{} = delivery, signal) do
    %{delivery | normalized_signal: signal}
  end

  @doc "Returns a JSON-safe delivery map with headers, payload, and metadata sanitized."
  @spec to_public_map(t()) :: map()
  def to_public_map(%__MODULE__{} = delivery) do
    %{
      provider: delivery.provider,
      event: delivery.event,
      delivery_id: delivery.delivery_id,
      received_at: DateTime.to_iso8601(delivery.received_at),
      signature_state: delivery.signature_state,
      duplicate?: delivery.duplicate?,
      source: delivery.source,
      headers: Sanitizer.sanitize(delivery.headers, :transport),
      payload: Sanitizer.sanitize(delivery.payload, :transport),
      normalized_signal: Sanitizer.sanitize(delivery.normalized_signal, :transport),
      metadata: Sanitizer.sanitize(delivery.metadata, :transport)
    }
  end

  defp attrs_map(attrs) when is_list(attrs), do: Map.new(attrs)
  defp attrs_map(attrs) when is_map(attrs), do: attrs
end

defimpl Inspect, for: Jido.Connect.WebhookDelivery do
  import Inspect.Algebra

  def inspect(delivery, opts) do
    delivery
    |> Jido.Connect.WebhookDelivery.to_public_map()
    |> to_doc(opts)
    |> then(&concat(["#Jido.Connect.WebhookDelivery<", &1, ">"]))
  end
end
