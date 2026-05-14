defmodule Jido.Connect.Google.Meet.Normalizer do
  @moduledoc "Normalizes Google Meet API payloads into stable package structs."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.Meet.{ConferenceRecord, Space}

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
end
