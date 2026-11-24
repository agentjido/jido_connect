defmodule Jido.Connect.Google.Meet.Triggers.Transcripts do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @readonly_scope "https://www.googleapis.com/auth/meetings.space.readonly"
  @scope_resolver Jido.Connect.Google.Meet.ScopeResolver

  triggers do
    poll :transcript_available do
      id("google.meet.transcript.available")
      resource(:transcript)
      verb(:watch)
      data_classification(:personal_data)
      label("Transcript available")

      description(
        "Poll Google Meet for transcripts whose Google Docs file was generated. " <>
          "Signals carry transcript metadata only, not transcript text."
      )

      interval_ms(300_000)
      checkpoint(:end_time_watermark)
      dedupe(%{key: [:transcript_name]})
      handler(Jido.Connect.Google.Meet.Handlers.Triggers.TranscriptPoller)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      signal do
        field(:transcript_name, :string)
        field(:conference_record_name, :string)
        field(:document_id, :string)
        field(:state, :string)
        field(:start_time, :string)
        field(:end_time, :string)
        field(:export_uri, :string)
      end
    end
  end
end
