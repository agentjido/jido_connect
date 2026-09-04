defmodule Jido.Connect.MicrosoftSharepoint.SiteList do
  @moduledoc "Normalized Microsoft Graph SharePoint `list` resource."

  @schema Zoi.struct(
            __MODULE__,
            %{
              list_id: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              display_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              web_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_date_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              last_modified_date_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              list: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              system: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              sharepoint_ids: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
