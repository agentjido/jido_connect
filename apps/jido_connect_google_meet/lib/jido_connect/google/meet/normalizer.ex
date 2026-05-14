defmodule Jido.Connect.Google.Meet.Normalizer do
  @moduledoc "Normalizes Google Meet API payloads into stable package structs."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.Meet.{ConferenceRecord, Recording, Space, Transcript}

  @doc "Normalizes a Google Meet space payload."
  @spec space(map()) :: {:ok, Space.t()} | {:error, term()}
  def space(payload) when is_map(payload) do
    %{
      space_name: Data.get(payload, "name"),
      meeting_uri: Data.get(payload, "meetingUri"),
      meeting_code: Data.get(payload, "meetingCode"),
      config: Data.get(payload, "config", %{}),
      active_conference: Data.get(payload, "activeConference"),
      phone_access: Data.get(payload, "phoneAccess", []),
      gateway_sip_access: Data.get(payload, "gatewaySipAccess", [])
    }
    |> Data.compact()
    |> Space.new()
  end

  def space(_payload), do: {:error, :invalid_space_payload}

  @doc "Normalizes a Google Meet conference record payload."
  @spec conference_record(map()) :: {:ok, ConferenceRecord.t()} | {:error, term()}
  def conference_record(payload) when is_map(payload) do
    %{
      conference_record_name: Data.get(payload, "name"),
      space: Data.get(payload, "space"),
      start_time: Data.get(payload, "startTime"),
      end_time: Data.get(payload, "endTime"),
      expire_time: Data.get(payload, "expireTime")
    }
    |> Data.compact()
    |> ConferenceRecord.new()
  end

  def conference_record(_payload), do: {:error, :invalid_conference_record_payload}

  @doc "Normalizes Google Meet recording metadata."
  @spec recording(map()) :: {:ok, Recording.t()} | {:error, term()}
  def recording(payload) when is_map(payload) do
    drive_destination = Data.get(payload, "driveDestination")

    %{
      recording_name: Data.get(payload, "name"),
      state: Data.get(payload, "state"),
      start_time: Data.get(payload, "startTime"),
      end_time: Data.get(payload, "endTime"),
      drive_destination: drive_destination,
      drive_file_id: Data.get(drive_destination, "file"),
      export_uri: Data.get(drive_destination, "exportUri")
    }
    |> Data.compact()
    |> Recording.new()
  end

  def recording(_payload), do: {:error, :invalid_recording_payload}

  @doc "Normalizes Google Meet transcript metadata."
  @spec transcript(map()) :: {:ok, Transcript.t()} | {:error, term()}
  def transcript(payload) when is_map(payload) do
    docs_destination = Data.get(payload, "docsDestination")

    %{
      transcript_name: Data.get(payload, "name"),
      state: Data.get(payload, "state"),
      start_time: Data.get(payload, "startTime"),
      end_time: Data.get(payload, "endTime"),
      docs_destination: docs_destination,
      document_id: Data.get(docs_destination, "document"),
      export_uri: Data.get(docs_destination, "exportUri")
    }
    |> Data.compact()
    |> Transcript.new()
  end

  def transcript(_payload), do: {:error, :invalid_transcript_payload}
end
