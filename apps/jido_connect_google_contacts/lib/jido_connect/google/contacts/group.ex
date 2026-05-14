defmodule Jido.Connect.Google.Contacts.Group do
  @moduledoc "Normalized Google Contacts contact group metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              resource_name: Zoi.string(),
              group_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              formatted_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              group_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              member_count: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              member_resource_names: Zoi.list(Zoi.string()) |> Zoi.default([]),
              client_data: Zoi.list(Zoi.map()) |> Zoi.default([]),
              etag: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
