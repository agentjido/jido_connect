defmodule Jido.Connect.Google.Meet.Client do
  @moduledoc "Google Meet API client boundary."

  alias Jido.Connect.Google.Meet.Client.{ConferenceRecords, Recordings, Spaces, Transcripts}

  defdelegate create_space(params, access_token), to: Spaces
  defdelegate get_space(params, access_token), to: Spaces
  defdelegate list_conference_records(params, access_token), to: ConferenceRecords
  defdelegate get_conference_record(params, access_token), to: ConferenceRecords
  defdelegate list_recordings(params, access_token), to: Recordings
  defdelegate get_recording(params, access_token), to: Recordings
  defdelegate list_transcripts(params, access_token), to: Transcripts
  defdelegate get_transcript(params, access_token), to: Transcripts
end
