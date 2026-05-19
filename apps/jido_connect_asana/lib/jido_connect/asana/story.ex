defmodule Jido.Connect.Asana.Story do
  @moduledoc "Normalized Asana story (comment or activity)."

  @schema Zoi.struct(
            __MODULE__,
            %{
              gid: Zoi.string(),
              resource_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              resource_subtype: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              text: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              html_text: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              is_pinned: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              sticker_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              num_likes: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              liked: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              created_by: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              target_gid: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              target_resource_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              task_gid: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              project_gid: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
