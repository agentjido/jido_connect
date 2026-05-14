defmodule Jido.Connect.Google.Drive.Reply do
  @moduledoc "Normalized Google Drive comment reply metadata and content."

  @schema Zoi.struct(
            __MODULE__,
            %{
              reply_id: Zoi.string(),
              kind: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              modified_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              action: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              author: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              deleted?: Zoi.boolean() |> Zoi.default(false),
              html_content: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              content: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
