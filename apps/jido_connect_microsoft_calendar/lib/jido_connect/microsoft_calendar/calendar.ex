defmodule Jido.Connect.MicrosoftCalendar.Calendar do
  @moduledoc """
  Normalized Microsoft Calendar metadata.

  Maps from Microsoft Graph `calendar` resources to a stable,
  provider-agnostic struct. Stores calendar identity, display name,
  owner metadata, and color — no event content.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              calendar_id: Zoi.string(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              color: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              hex_color: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              is_default_calendar: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              is_shared: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              is_tallying_replies: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              owner: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              calendar_group_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              can_edit: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              can_share: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              can_view_private_items: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
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
