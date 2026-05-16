defmodule Jido.Connect.Jira.User do
  @moduledoc "Normalized Jira user."

  @schema Zoi.struct(
            __MODULE__,
            %{
              account_id: Zoi.string(),
              display_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              email: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              active: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              avatar_urls: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              time_zone: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              locale: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              account_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
