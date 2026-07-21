defmodule Jido.Connect.Google.Forms.BatchUpdateResult do
  @moduledoc "Normalized Google Forms batchUpdate result."

  @schema Zoi.struct(
            __MODULE__,
            %{
              form_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              replies: Zoi.list(Zoi.map()) |> Zoi.default([]),
              write_control: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
