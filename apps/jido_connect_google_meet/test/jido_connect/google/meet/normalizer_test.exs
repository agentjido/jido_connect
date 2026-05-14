defmodule Jido.Connect.Google.Meet.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Meet.{Normalizer, Space}

  test "normalizes Meet space payloads" do
    assert {:ok,
            %Space{
              space_name: "spaces/abc-mnop-xyz",
              meeting_uri: "https://meet.google.com/abc-mnop-xyz",
              meeting_code: "abc-mnop-xyz",
              phone_access: [%{"regionCode" => "US"}],
              gateway_sip_access: [%{"uri" => "sip:123@example.com"}]
            }} =
             Normalizer.space(%{
               "name" => "spaces/abc-mnop-xyz",
               "meetingUri" => "https://meet.google.com/abc-mnop-xyz",
               "meetingCode" => "abc-mnop-xyz",
               "config" => %{"accessType" => "OPEN"},
               "activeConference" => %{"conferenceRecord" => "conferenceRecords/abc"},
               "phoneAccess" => [%{"regionCode" => "US"}],
               "gatewaySipAccess" => [%{"uri" => "sip:123@example.com"}]
             })
  end

  test "rejects malformed Meet space payloads" do
    assert {:error, _error} = Normalizer.space(%{"meetingCode" => "missing-name"})
    assert {:error, :invalid_space_payload} = Normalizer.space(nil)
  end
end
