defmodule Jido.Connect.GitLab.Job do
  @moduledoc "Normalized GitLab CI/CD job."

  alias Jido.Connect.GitLab.User

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.number(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              stage: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              status: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              ref: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              tag: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              user: User.schema() |> Zoi.nullish() |> Zoi.optional(),
              pipeline_id: Zoi.number() |> Zoi.nullish() |> Zoi.optional(),
              web_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              runner: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
