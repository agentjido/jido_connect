defmodule Jido.Connect.Google.SearchConsole.Sitemap do
  @moduledoc "Normalized Google Search Console sitemap metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              path: Zoi.string(),
              last_submitted: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              is_pending: Zoi.boolean() |> Zoi.default(false),
              last_downloaded: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              error_count: Zoi.integer() |> Zoi.default(0),
              warnings_count: Zoi.integer() |> Zoi.default(0),
              type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              contents: Zoi.list(Zoi.map()) |> Zoi.default([]),
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
