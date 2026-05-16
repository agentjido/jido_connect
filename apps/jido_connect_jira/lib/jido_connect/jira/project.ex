defmodule Jido.Connect.Jira.Project do
  @moduledoc "Normalized Jira project."

  alias Jido.Connect.Jira.User

  @schema Zoi.struct(
            __MODULE__,
            %{
              key: Zoi.string(),
              id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              project_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              style: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              lead: User.schema() |> Zoi.nullish() |> Zoi.optional(),
              category: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              avatar_urls: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
