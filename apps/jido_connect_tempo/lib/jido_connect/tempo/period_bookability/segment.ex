defmodule Jido.Connect.Tempo.PeriodBookability.Segment do
  @moduledoc """
  Approval evidence of one Tempo period within a requested range.

  | Field | Meaning |
  | --- | --- |
  | `from`, `to` | the part of the requested range that lies in this period, both inclusive |
  | `period_from`, `period_to` | the full period as Tempo reports it |
  | `approval_status` | Tempo's approval `status.key` as sent, or `nil` when no status was read |
  | `approval_updated_at` | Tempo's `status.updatedAt` as sent, or `nil` |
  | `approval_error` | `nil` when the approval read returned an approval, else the `reason`, `status` and `retry_after` of the failed read |
  | `closure_evidence` | always `:unknown` |
  | `state` | `:blocked` or `:unknown`, derived from `approval_status` |

  See `Jido.Connect.Tempo.PeriodBookability` for the derivation.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              from: Zoi.ISO.date(),
              to: Zoi.ISO.date(),
              period_from: Zoi.ISO.date(),
              period_to: Zoi.ISO.date(),
              approval_status: Zoi.string() |> Zoi.min(1) |> Zoi.nullish() |> Zoi.optional(),
              approval_updated_at: Zoi.string() |> Zoi.min(1) |> Zoi.nullish() |> Zoi.optional(),
              approval_error:
                Zoi.map(%{
                  reason: Zoi.atom(),
                  status: Zoi.integer() |> Zoi.nullable(),
                  retry_after: Zoi.integer() |> Zoi.nullable()
                })
                |> Zoi.nullish()
                |> Zoi.optional(),
              closure_evidence: Zoi.literal(:unknown),
              state: Zoi.enum([:blocked, :unknown])
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @doc false
  def schema, do: @schema

  @doc "Builds a segment, or raises when an attribute is invalid."
  @spec new!(map()) :: t()
  def new!(attrs), do: Zoi.parse!(@schema, attrs)
end
