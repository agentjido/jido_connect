defmodule Jido.Connect.MicrosoftOutlook.Recipient do
  @moduledoc """
  Normalized Outlook Mail recipient (sender, to, cc, bcc).

  Microsoft Graph represents recipients as:

      %{
        "emailAddress" => %{
          "name" => "Megan Bowen",
          "address" => "meganb@contoso.com"
        }
      }

  This struct flattens the nested `emailAddress` into top-level fields.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              address: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
