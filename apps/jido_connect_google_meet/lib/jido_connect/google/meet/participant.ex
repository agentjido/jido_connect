defmodule Jido.Connect.Google.Meet.Participant do
  @moduledoc """
  Normalized Google Meet conference participant metadata.

  `participant_name` is the resource name
  `conferenceRecords/<record>/participants/<participant>` that a transcript
  entry names as its speaker. Google sends exactly one user kind per
  participant, and `user_type` names it:

  - `"signed_in_user"`: a signed-in Google user. `user` is the user's
    resource name `users/<id>`, and `signed_in_user` holds the raw
    `signedinUser` map.
  - `"anonymous_user"`: a participant without a Google account.
    `anonymous_user` holds the raw `anonymousUser` map.
  - `"phone_user"`: a participant who dialed in. `phone_user` holds the raw
    `phoneUser` map.

  `display_name` is the `displayName` of that user kind. `user_type`, `user`
  and `display_name` are `nil` when the response leaves the user kind out, as
  under a `fields` projection. `earliest_start_time` and `latest_end_time` are
  the first join and the last leave of the participant in the conference.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              participant_name: Zoi.string(),
              user_type: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              user: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              display_name: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              signed_in_user: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              anonymous_user: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              phone_user: Zoi.map() |> Zoi.nullish() |> Zoi.optional(),
              earliest_start_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              latest_end_time: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
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
