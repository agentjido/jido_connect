defmodule Jido.Connect.Google.Calendar.AclRule do
  @moduledoc "Normalized Google Calendar ACL rule metadata."

  @schema Zoi.struct(
            __MODULE__,
            %{
              acl_rule_id: Zoi.string(),
              calendar_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              role: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              scope_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              scope_value: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              etag: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              kind: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
