defmodule Jido.Connect.Google.Meet.Normalizer do
  @moduledoc "Normalizes Google Meet API payloads into stable package structs."

  alias Jido.Connect.Data

  alias Jido.Connect.Google.Meet.{
    ConferenceRecord,
    Participant,
    Recording,
    Space,
    Transcript,
    TranscriptEntry
  }

  # A participant carries exactly one of these user kinds: payload key,
  # `user_type` value and struct field.
  @participant_user_kinds [
    {"signedinUser", "signed_in_user", :signed_in_user},
    {"anonymousUser", "anonymous_user", :anonymous_user},
    {"phoneUser", "phone_user", :phone_user}
  ]

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

  @doc """
  Normalizes a Google Meet conference participant payload.

  The user kind present in the payload sets `user_type`, `display_name` and,
  for a signed-in user, `user`. A payload without a user kind, as under a
  `fields` projection, leaves them `nil`; a payload with more than one is
  rejected. A payload whose `name` is no participant resource name
  `conferenceRecords/<record>/participants/<participant>` is rejected as
  `:not_a_participant`: Google answers the name of another resource, such as
  a transcript entry, with that resource.
  """
  @spec participant(map()) :: {:ok, Participant.t()} | {:error, term()}
  def participant(payload) when is_map(payload) do
    with :ok <- participant_name(Data.get(payload, "name")) do
      case Enum.filter(@participant_user_kinds, fn {key, _type, _field} ->
             Data.get(payload, key) != nil
           end) do
        [] -> build_participant(payload, %{})
        [kind] -> build_participant(payload, participant_user(payload, kind))
        _several -> {:error, :ambiguous_participant_user}
      end
    end
  end

  def participant(_payload), do: {:error, :invalid_participant_payload}

  defp participant_name(name) when is_binary(name) do
    if name =~ ~r{\AconferenceRecords/[^/]+/participants/[^/]+\z},
      do: :ok,
      else: {:error, :not_a_participant}
  end

  defp participant_name(_name), do: {:error, :not_a_participant}

  defp build_participant(payload, user_attrs) do
    %{
      participant_name: Data.get(payload, "name"),
      earliest_start_time: Data.get(payload, "earliestStartTime"),
      latest_end_time: Data.get(payload, "latestEndTime")
    }
    |> Map.merge(user_attrs)
    |> Data.compact()
    |> Participant.new()
  end

  defp participant_user(payload, {key, user_type, field}) do
    user = Data.get(payload, key)

    %{
      field => user,
      user_type: user_type,
      user: Data.get(user, "user"),
      display_name: Data.get(user, "displayName")
    }
  end

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

  @doc "Normalizes a Google Meet transcript entry payload."
  @spec transcript_entry(map()) :: {:ok, TranscriptEntry.t()} | {:error, term()}
  def transcript_entry(payload) when is_map(payload) do
    %{
      entry_name: Data.get(payload, "name"),
      participant: Data.get(payload, "participant"),
      text: Data.get(payload, "text"),
      language_code: Data.get(payload, "languageCode"),
      start_time: Data.get(payload, "startTime"),
      end_time: Data.get(payload, "endTime")
    }
    |> Data.compact()
    |> TranscriptEntry.new()
  end

  def transcript_entry(_payload), do: {:error, :invalid_transcript_entry_payload}
end
