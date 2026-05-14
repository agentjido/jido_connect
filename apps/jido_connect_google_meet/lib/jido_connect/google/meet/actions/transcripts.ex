defmodule Jido.Connect.Google.Meet.Actions.Transcripts do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @readonly_scope "https://www.googleapis.com/auth/meetings.space.readonly"
  @scope_resolver Jido.Connect.Google.Meet.ScopeResolver

  actions do
    action :list_transcripts do
      id("google.meet.transcript.list")
      resource(:transcript)
      verb(:list)
      data_classification(:personal_data)
      label("List Meet transcripts")
      description("List Google Meet transcript metadata for a conference record.")
      handler(Jido.Connect.Google.Meet.Handlers.Actions.ListTranscripts)
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
        field(:transcripts, {:array, :map})
        field(:next_page_token, :string)
      end
    end

    action :get_transcript do
      id("google.meet.transcript.get")
      resource(:transcript)
      verb(:get)
      data_classification(:personal_data)
      label("Get Meet transcript")
      description("Fetch Google Meet transcript metadata without fetching transcript content.")
      handler(Jido.Connect.Google.Meet.Handlers.Actions.GetTranscript)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:transcript_name, :string,
          required?: true,
          example: "conferenceRecords/abc/transcripts/def"
        )

        field(:fields, :string)
      end

      output do
        field(:transcript, :map)
      end
    end
  end
end
