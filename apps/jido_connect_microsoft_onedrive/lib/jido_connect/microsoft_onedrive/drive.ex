defmodule Jido.Connect.MicrosoftOnedrive.Drive do
  @moduledoc "Normalized Microsoft Graph `drive` resource metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              drive_id: Zoi.string(),
              drive_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              web_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              quota: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              owner: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              created_date_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              last_modified_date_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
