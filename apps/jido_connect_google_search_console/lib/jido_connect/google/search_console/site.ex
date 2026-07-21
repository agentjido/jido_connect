defmodule Jido.Connect.Google.SearchConsole.Site do
  @moduledoc "Normalized Google Search Console site/property metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              site_url: Zoi.string(),
              permission_level: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
