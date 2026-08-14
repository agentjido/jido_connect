defmodule Jido.Connect.Nextcloud.Share do
  @moduledoc "Normalized Nextcloud OCS share metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              share_id: Zoi.string(),
              path: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              item_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              item_source: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              file_source: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              file_target: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              share_type: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              share_with: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              share_with_display_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              permissions: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              token: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              expiration: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              note: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              label: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
