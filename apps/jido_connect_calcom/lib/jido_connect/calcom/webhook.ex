defmodule Jido.Connect.Calcom.Webhook do
  @moduledoc """
  Cal.com webhook struct and event verification/normalization facade.
  """

  alias Jido.Connect.Calcom.Webhook.{Normalizer, Verification}

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              subscriber_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              active: Zoi.boolean() |> Zoi.default(false),
              triggers: Zoi.list(Zoi.string()) |> Zoi.default([]),
              payload_template: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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

  # Verification delegates

  defdelegate verify_signature(body, headers, webhook_secret), to: Verification
  defdelegate verify_request(body, headers, webhook_secret), to: Verification
  defdelegate verify_delivery(body, headers, webhook_secret, opts \\ []), to: Verification

  # Normalization delegates

  defdelegate normalize_signal(delivery), to: Normalizer
  defdelegate normalize_signal(event, payload), to: Normalizer
  defdelegate normalize_event(payload), to: Normalizer
end
