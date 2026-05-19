defmodule Jido.Connect.MicrosoftOnedrive.Permission do
  @moduledoc "Normalized Microsoft Graph `permission` resource metadata."

  alias Jido.Connect.MicrosoftOnedrive.SharingLink

  @schema Zoi.struct(
            __MODULE__,
            %{
              permission_id: Zoi.string(),
              roles: Zoi.list(Zoi.string()) |> Zoi.default([]),
              link: SharingLink.schema() |> Zoi.nullish() |> Zoi.optional(),
              granted_to: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              granted_to_identities: Zoi.list(Zoi.map()) |> Zoi.default([]),
              inherited_from: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              share_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              has_password: Zoi.boolean() |> Zoi.nullish() |> Zoi.optional(),
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
