defmodule Jido.Connect.Google.Meet.Actions.Recordings do
  @moduledoc false

  use Spark.Dsl.Fragment, of: Jido.Connect

  @readonly_scope "https://www.googleapis.com/auth/meetings.space.readonly"
  @scope_resolver Jido.Connect.Google.Meet.ScopeResolver

  actions do
    action :list_recordings do
      id("google.meet.recording.list")
      resource(:recording)
      verb(:list)
      data_classification(:personal_data)
      label("List Meet recordings")
      description("List Google Meet recording metadata for a conference record.")
      handler(Jido.Connect.Google.Meet.Handlers.Actions.ListRecordings)
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
        field(:recordings, {:array, :map})
        field(:next_page_token, :string)
      end
    end

    action :get_recording do
      id("google.meet.recording.get")
      resource(:recording)
      verb(:get)
      data_classification(:personal_data)
      label("Get Meet recording")
      description("Fetch Google Meet recording metadata without downloading the recording file.")
      handler(Jido.Connect.Google.Meet.Handlers.Actions.GetRecording)
      effect(:read)

      access do
        auth(:user)
        scopes([@readonly_scope], resolver: @scope_resolver)
      end

      input do
        field(:recording_name, :string,
          required?: true,
          example: "conferenceRecords/abc/recordings/def"
        )

        field(:fields, :string)
      end

      output do
        field(:recording, :map)
      end
    end
  end
end
