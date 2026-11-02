defmodule Jido.Connect.Google.Meet.TranscriptEntry do
  @moduledoc """
  Normalized Google Meet transcript entry: one spoken segment with its text,
  speaking participant, language and time span.

  Google deletes transcript entries 30 days after the conference ends. Entries
  can differ from the transcript document when someone edited that document.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              entry_name: Zoi.string(),
              participant: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              text: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              language_code: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              start_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              end_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
