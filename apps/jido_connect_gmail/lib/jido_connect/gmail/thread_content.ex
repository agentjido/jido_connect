defmodule Jido.Connect.Gmail.ThreadContent do
  @moduledoc """
  Complete content of a Gmail thread, returned by
  `google.gmail.thread.content.get`.

  `messages` holds every message of the thread as a
  `Jido.Connect.Gmail.MessageContent`, sent replies included, ordered by the
  numeric value of Gmail's `internalDate`. Messages with the same
  `internalDate` keep Gmail's order.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              thread_id: Zoi.string(),
              history_id: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              messages: Zoi.list(Jido.Connect.Gmail.MessageContent.schema()) |> Zoi.default([]),
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
