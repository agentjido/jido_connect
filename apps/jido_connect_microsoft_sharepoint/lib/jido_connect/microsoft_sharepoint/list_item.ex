defmodule Jido.Connect.MicrosoftSharepoint.ListItem do
  @moduledoc "Normalized Microsoft Graph SharePoint `listItem` resource."

  @schema Zoi.struct(
            __MODULE__,
            %{
              item_id: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              web_url: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              etag: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_date_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              last_modified_date_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              created_by: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              last_modified_by: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              content_type: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              fields: Zoi.map() |> Zoi.default(%{}),
              sharepoint_ids: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              deleted: Zoi.boolean() |> Zoi.default(false),
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
