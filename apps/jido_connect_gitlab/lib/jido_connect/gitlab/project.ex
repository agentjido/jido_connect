defmodule Jido.Connect.GitLab.Project do
  @moduledoc "Normalized GitLab project."

  alias Jido.Connect.GitLab.User

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.number(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              path: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              path_with_namespace: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              default_branch: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              visibility: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              web_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              ssh_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              http_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              namespace: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              owner: User.schema() |> Zoi.nullish() |> Zoi.optional(),
              star_count: Zoi.number() |> Zoi.nullish() |> Zoi.optional(),
              forks_count: Zoi.number() |> Zoi.nullish() |> Zoi.optional(),
              open_issues_count: Zoi.number() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              updated_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
