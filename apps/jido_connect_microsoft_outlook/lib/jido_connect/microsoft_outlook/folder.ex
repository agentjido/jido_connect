defmodule Jido.Connect.MicrosoftOutlook.Folder do
  @moduledoc """
  Normalized Outlook Mail folder metadata.

  Maps from Microsoft Graph `mailFolder` resources to a stable,
  provider-agnostic struct for folder listing and retrieval.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              folder_id: Zoi.string(),
              display_name: Zoi.string(),
              parent_folder_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              child_folder_count: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              unread_item_count: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              total_item_count: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              well_known_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
