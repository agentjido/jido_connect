defmodule Jido.Connect.Asana.Project do
  @moduledoc "Normalized Asana project."

  @schema Zoi.struct(
            __MODULE__,
            %{
              gid: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              resource_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              color: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              archived: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              public: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              due_date: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              due_on: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              start_on: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              notes: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              html_notes: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              current_status: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              default_view: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              workspace_gid: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              team_gid: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              owner_gid: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              modified_at: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
