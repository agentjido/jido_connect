defmodule Jido.Connect.Google.Calendar.Calendar do
  @moduledoc "Normalized Google Calendar calendar-list entry metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              calendar_id: Zoi.string(),
              etag: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              kind: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              summary: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              summary_override: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              location: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              time_zone: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              data_owner: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              access_role: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              background_color: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              foreground_color: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              color_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              selected?: Zoi.boolean() |> Zoi.default(false),
              hidden?: Zoi.boolean() |> Zoi.default(false),
              primary?: Zoi.boolean() |> Zoi.default(false),
              deleted?: Zoi.boolean() |> Zoi.default(false),
              auto_accept_invitations?: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              conference_properties: Zoi.map() |> Zoi.default(%{}),
              default_reminders: Zoi.list(Zoi.map()) |> Zoi.default([]),
              notification_settings: Zoi.map() |> Zoi.default(%{}),
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
