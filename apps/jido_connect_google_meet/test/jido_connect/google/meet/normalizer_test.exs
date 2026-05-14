defmodule Jido.Connect.Google.Meet.NormalizerTest do
  use ExUnit.Case, async: true

  alias Jido.Connect.Google.Meet.{ConferenceRecord, Normalizer, Space}

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

  test "normalizes Meet conference record payloads" do
    assert {:ok,
            %ConferenceRecord{
              conference_record_name: "conferenceRecords/abc",
              space: "spaces/abc",
              start_time: "2026-05-14T18:00:00Z",
              end_time: "2026-05-14T19:00:00Z",
              expire_time: "2026-06-13T19:00:00Z"
            }} =
             Normalizer.conference_record(%{
               "name" => "conferenceRecords/abc",
               "space" => "spaces/abc",
               "startTime" => "2026-05-14T18:00:00Z",
               "endTime" => "2026-05-14T19:00:00Z",
               "expireTime" => "2026-06-13T19:00:00Z"
             })
  end

  test "rejects malformed Meet conference record payloads" do
    assert {:error, _error} = Normalizer.conference_record(%{"space" => "spaces/abc"})
    assert {:error, :invalid_conference_record_payload} = Normalizer.conference_record(nil)
  end
end
