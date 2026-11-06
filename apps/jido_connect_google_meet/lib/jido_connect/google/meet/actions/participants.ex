defmodule Jido.Connect.Google.Meet.Actions.Participants do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @readonly_scope "https://www.googleapis.com/auth/meetings.space.readonly"
  @scope_resolver Jido.Connect.Google.Meet.ScopeResolver

  actions do
    action :list_participants do
      id("google.meet.participant.list")
      resource(:participant)
      verb(:list)
      data_classification(:personal_data)
      label("List Meet participants")

      description(
        "List the participants of a Google Meet conference record with display name and user identity."
      )

      handler(Jido.Connect.Google.Meet.Handlers.Actions.ListParticipants)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:conference_record_name, :string,
          required?: true,
          example: "conferenceRecords/abc"
        )

        field(:page_size, :integer, default: 10)
        field(:page_token, :string)
        field(:fields, :string)
      end

      output do
        field(:participants, {:array, :map})
        field(:next_page_token, :string)
      end
    end

    action :get_participant do
      id("google.meet.participant.get")
      resource(:participant)
      verb(:get)
      data_classification(:personal_data)
      label("Get Meet participant")

      description(
        "Fetch a Google Meet conference participant, such as a transcript entry's speaker, with display name and user identity."
      )

      handler(Jido.Connect.Google.Meet.Handlers.Actions.GetParticipant)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:participant_name, :string,
          required?: true,
          example: "conferenceRecords/abc/participants/def"
        )

        field(:fields, :string)
      end

      output do
        field(:participant, :map)
      end
    end
  end
end
