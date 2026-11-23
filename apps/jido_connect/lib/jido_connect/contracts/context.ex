defmodule Jido.Connect.Context do
  @moduledoc """
  Host-provided context for connection selection and access.

  A host can supply a resolved connection or a selector. Generated Actions
  and Sensors can resolve a selector with a `{module, function}` callback.
  The context can also name a policy and a credential resolver.

  Keep credential material in the host's credential store. A connection
  refers to it through `Jido.Connect.Connection.credential_ref`.
  """

  alias Jido.Connect.{Connection, ConnectionSelector}

  @schema Zoi.struct(
            __MODULE__,
            %{
              tenant_id: Zoi.string(),
              actor: Zoi.map(),
              connection: Connection.schema() |> Zoi.nullish() |> Zoi.optional(),
              connection_selector: ConnectionSelector.schema() |> Zoi.nullish() |> Zoi.optional(),
              policy: Zoi.module() |> Zoi.nullish() |> Zoi.optional(),
              credential_resolver: Zoi.module() |> Zoi.nullish() |> Zoi.optional(),
              connection_resolver:
                Zoi.tuple({Zoi.module(), Zoi.atom()}) |> Zoi.nullish() |> Zoi.optional(),
              claims: Zoi.map() |> Zoi.default(%{}),
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
