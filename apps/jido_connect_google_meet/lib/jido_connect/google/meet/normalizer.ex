defmodule Jido.Connect.Google.Meet.Normalizer do
  @moduledoc "Normalizes Google Meet API payloads into stable package structs."

  alias Jido.Connect.Data
  alias Jido.Connect.Google.Meet.Space

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
end
