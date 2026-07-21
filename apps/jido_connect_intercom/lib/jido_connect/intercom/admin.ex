defmodule Jido.Connect.Intercom.Admin do
  @moduledoc "Normalized Intercom admin (teammate)."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              email: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              job_title: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              away_mode_enabled: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              away_mode_reassign: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              has_inbox_seat: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              team_ids: Zoi.list(Zoi.string()) |> Zoi.default([]),
              avatar: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
end
