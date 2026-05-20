defmodule Jido.Connect.GitLab.Commit do
  @moduledoc "Normalized GitLab commit."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              short_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              title: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              message: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              author_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              author_email: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              authored_date: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              committer_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              committer_email: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              committed_date: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              web_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
