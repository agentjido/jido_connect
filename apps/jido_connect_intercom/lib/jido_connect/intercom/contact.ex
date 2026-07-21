defmodule Jido.Connect.Intercom.Contact do
  @moduledoc "Normalized Intercom contact."

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.string(),
              workspace_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              external_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              email: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              phone: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              avatar: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              role: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              has_hard_bounced: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              marked_email_as_spam: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              unsubscribed_from_emails: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              updated_at: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              signed_up_at: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              last_seen_at: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              last_replied_at: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              last_email_opened_at: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              last_contacted_at: Zoi.integer() |> Zoi.nullish() |> Zoi.optional(),
              browser: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              browser_version: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              os: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              location: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              tags: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              companies: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              custom_attributes: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
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
