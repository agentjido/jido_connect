defmodule Jido.Connect.GitLab.Pipeline do
  @moduledoc "Normalized GitLab CI/CD pipeline."

  alias Jido.Connect.GitLab.User

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.number(),
              sha: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              ref: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              status: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              source: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              user: User.schema() |> Zoi.nullish() |> Zoi.optional(),
              project_id: Zoi.number() |> Zoi.nullish() |> Zoi.optional(),
              web_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              updated_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              started_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              finished_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
