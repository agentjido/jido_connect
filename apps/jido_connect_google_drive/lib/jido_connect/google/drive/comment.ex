defmodule Jido.Connect.Google.Drive.Comment do
  @moduledoc "Normalized Google Drive comment metadata and content."

  @schema Zoi.struct(
            __MODULE__,
            %{
              comment_id: Zoi.string(),
              kind: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              modified_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              resolved?: Zoi.boolean() |> Zoi.default(false),
              anchor: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              author: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              deleted?: Zoi.boolean() |> Zoi.default(false),
              html_content: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              content: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              quoted_file_content: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              replies: Zoi.list(Zoi.map()) |> Zoi.default([]),
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
