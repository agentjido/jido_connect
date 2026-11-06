defmodule Jido.Connect.Google.Meet.ParticipantsLiveSmokeTest do
  @moduledoc """
  Live checks that resolve the speakers of the prepared transcript entries
  into conference participants through the participant actions.

      mix test --only live_smoke

  The checks need the Meet data prepared on 2026-10-30:
  `GOOGLE_MEET_TRANSCRIPT` and its conference record
  `GOOGLE_MEET_CONFERENCE_RECORD`, and the earlier conference record in the
  same space, which ended in the same window between 16:00 and 18:00 UTC and
  has two participants. Google deletes a record 30 days after its conference
  ended; from then on `LiveMeet.prepared!/1` skips the checks that need the
  prepared record or transcript. The earlier record is found through the
  window and has no variable of its own, so its check is skipped on the
  prepared record's answer. It expires first, on 2026-11-29 at 16:54:56 UTC,
  the prepared record at 17:19:37 UTC; a run in those 25 minutes fails the
  check of the earlier record instead of skipping it. See
  `docs/live_smoke_tests.md` for the variables and the recording mode.

  The earlier record's participants include a person outside the test
  account. The sanitizer replaces display names and Google user IDs in the
  recordings. A failing assertion here prints resource names at most, never
  a display name: participants are compared with messages of their own, and
  the actions run through `invoke!/3` and `refused!/3`, which reduce an
  error to its type, provider, reason and status and print no successful
  result.
  """

  use ExUnit.Case, async: false
  use Jido.Connect.TestSupport.LiveSmoke

  alias Jido.Connect
  alias Jido.Connect.Error.ProviderError
  alias Jido.Connect.Google.Meet
  alias Jido.Connect.Google.Meet.Client
  alias Jido.Connect.Google.Meet.TestSupport.LiveMeet

  require LiveMeet

  @req_options {:jido_connect_google, :google_req_options}
  @readonly_scope "https://www.googleapis.com/auth/meetings.space.readonly"

  # The prepared conference records ended inside this window.
  @prepared_window_start ~U[2026-10-30 16:00:00Z]
  @prepared_window_end ~U[2026-10-30 18:00:00Z]

  # Google returns at most 100 transcript entries per page.
  @entry_page_size 100
  @page_limit 10

  @user_types ["signed_in_user", "anonymous_user", "phone_user"]

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_MEET_CONFERENCE_RECORD", "GOOGLE_MEET_TRANSCRIPT"])
  @tag LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD", "GOOGLE_MEET_TRANSCRIPT"])
  @tag timeout: :timer.minutes(2)
  test "resolves every speaker of the prepared transcript entries", %{env: env} do
    token = env["GOOGLE_ACCESS_TOKEN"]
    record = env["GOOGLE_MEET_CONFERENCE_RECORD"]

    speakers =
      env["GOOGLE_MEET_TRANSCRIPT"]
      |> entries(token)
      |> Enum.map(& &1.participant)
      |> Enum.uniq()

    assert speakers != [], "the prepared transcript has no entries"

    page = invoke!("google.meet.participant.list", %{conference_record_name: record}, token)
    refute Map.has_key?(page, :next_page_token), "the participant list has a second page"
    names = Enum.map(page.participants, & &1.participant_name)
    assert speakers -- names == []

    LiveSmoke.record(@req_options, :google_meet, "participant_get")

    speakers
    |> Enum.with_index(1)
    |> Enum.each(fn {speaker, index} ->
      %{participant: participant} =
        invoke!("google.meet.participant.get", %{participant_name: speaker}, token)

      listed = Enum.find(page.participants, &(&1.participant_name == speaker))
      assert participant == listed, "speaker #{index} differs between get and list"
      assert_identity(participant)
    end)

    # A field projection leaves everything but the name out of the response.
    LiveSmoke.record(@req_options, :google_meet, "participant_get_name_only")
    [speaker | _rest] = speakers

    %{participant: named} =
      invoke!("google.meet.participant.get", %{participant_name: speaker, fields: "name"}, token)

    assert named.participant_name == speaker

    assert is_nil(named.user_type) and is_nil(named.user) and is_nil(named.display_name),
           "the name-only participant carries a user"
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_MEET_CONFERENCE_RECORD"])
  @tag LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD"])
  @tag timeout: :timer.minutes(2)
  test "pages through the participants of the earlier prepared conference record", %{env: env} do
    token = env["GOOGLE_ACCESS_TOKEN"]
    earlier = earlier_record!(env["GOOGLE_MEET_CONFERENCE_RECORD"], token)

    reference =
      invoke!(
        "google.meet.participant.list",
        %{conference_record_name: earlier, page_size: 100},
        token
      )

    refute Map.has_key?(reference, :next_page_token), "the participant list has a second page"

    # The page token encodes the next participant's Google user ID in Base64,
    # where the sanitizer does not look, so the recording keeps a placeholder.
    LiveSmoke.record(@req_options, :google_meet, "participants", fields: ["nextPageToken"])

    pages = participant_pages(earlier, token)
    participants = Enum.flat_map(pages, & &1.participants)
    names = Enum.map(participants, & &1.participant_name)

    assert length(pages) >= 2
    assert Enum.map(pages, &length(&1.participants)) == List.duplicate(1, length(pages))
    assert names == Enum.map(reference.participants, & &1.participant_name)
    assert Enum.uniq(names) == names
    assert Enum.all?(names, &String.starts_with?(&1, earlier <> "/participants/"))

    for participant <- participants do
      assert_identity(participant)
    end
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_MEET_CONFERENCE_RECORD"])
  @tag LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD"])
  test "rejects a missing participant of the prepared conference record", %{env: env} do
    missing =
      env["GOOGLE_MEET_CONFERENCE_RECORD"] <>
        "/participants/00000000-0000-0000-0000-000000000000"

    LiveSmoke.record(@req_options, :google_meet, "participant_not_found")

    assert {ProviderError, :google, :http_error, 404} =
             refused!(
               "google.meet.participant.get",
               %{participant_name: missing},
               env["GOOGLE_ACCESS_TOKEN"]
             )
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN", "GOOGLE_MEET_CONFERENCE_RECORD", "GOOGLE_MEET_TRANSCRIPT"])
  @tag LiveMeet.prepared!(["GOOGLE_MEET_CONFERENCE_RECORD", "GOOGLE_MEET_TRANSCRIPT"])
  test "rejects a transcript entry name in place of its speaker", %{env: env} do
    token = env["GOOGLE_ACCESS_TOKEN"]
    params = %{transcript_name: env["GOOGLE_MEET_TRANSCRIPT"], page_size: 1}
    assert {:ok, %{transcript_entries: [entry]}} = Client.list_transcript_entries(params, token)

    # Google answers an entry's own name with the entry, not with a participant.
    LiveSmoke.record(@req_options, :google_meet, "participant_get_transcript_entry",
      fields: ["text"]
    )

    assert {ProviderError, :google, :invalid_response, nil} =
             refused!("google.meet.participant.get", %{participant_name: entry.entry_name}, token)
  end

  @tag env!(["GOOGLE_ACCESS_TOKEN"])
  test "rejects the participants of an invalid conference record", %{env: env} do
    LiveSmoke.record(@req_options, :google_meet, "participants_invalid_record")

    assert {ProviderError, :google, :http_error, 400} =
             refused!(
               "google.meet.participant.list",
               %{conference_record_name: "conferenceRecords/not-a-conference", page_size: 1},
               env["GOOGLE_ACCESS_TOKEN"]
             )
  end

  defp assert_identity(participant) do
    assert participant.user_type in @user_types

    assert is_binary(participant.display_name) and participant.display_name != "",
           "a participant has no display name"

    if participant.user_type == "signed_in_user" do
      assert "users/" <> _id = participant.user
    end
  end

  defp earlier_record!(prepared, token) do
    window =
      ~s(end_time>="#{DateTime.to_iso8601(@prepared_window_start)}" AND ) <>
        ~s(end_time<="#{DateTime.to_iso8601(@prepared_window_end)}")

    assert {:ok, %{conference_records: records}} =
             Client.list_conference_records(%{filter: window, page_size: 100}, token)

    assert [earlier] = Enum.map(records, & &1.conference_record_name) -- [prepared]
    earlier
  end

  defp entries(transcript, token, page_token \\ nil, pages \\ 0) do
    assert pages < @page_limit, "the prepared transcript has too many entries"
    params = %{transcript_name: transcript, page_size: @entry_page_size, page_token: page_token}
    assert {:ok, page} = Client.list_transcript_entries(params, token)

    case page do
      %{next_page_token: next} when is_binary(next) ->
        page.transcript_entries ++ entries(transcript, token, next, pages + 1)

      _last ->
        page.transcript_entries
    end
  end

  # Follows next_page_token one participant per page and fails past the limit.
  defp participant_pages(record, token, page_token \\ nil, pages \\ []) do
    assert length(pages) < @page_limit, "the conference record has too many participants"
    # The action's schema takes a page token only as a string.
    input =
      %{conference_record_name: record, page_size: 1, page_token: page_token}
      |> Map.reject(fn {_key, value} -> is_nil(value) end)

    page = invoke!("google.meet.participant.list", input, token)
    pages = [page | pages]

    case page do
      %{next_page_token: next} when is_binary(next) ->
        participant_pages(record, token, next, pages)

      _last ->
        Enum.reverse(pages)
    end
  end

  # The result of an action that succeeds. An error fails the test with the
  # action and the error's outline.
  defp invoke!(action_id, input, token) do
    case invoke(action_id, input, token) do
      {:ok, result} -> result
      {:error, error} -> flunk("#{action_id} failed: #{inspect(outline(error))}")
    end
  end

  # The outline of the error of an action that Google refuses. A success
  # fails the test without the participants it returned.
  defp refused!(action_id, input, token) do
    case invoke(action_id, input, token) do
      {:error, error} -> outline(error)
      {:ok, _result} -> flunk("#{action_id} succeeded")
    end
  end

  # An error's type, provider, reason and status, without its details, where
  # Google's response body can hold a display name.
  defp outline(error) do
    {error.__struct__, Map.get(error, :provider), Map.get(error, :reason),
     Map.get(error, :status)}
  end

  defp invoke(action_id, input, token) do
    connection =
      Connect.Connection.new!(%{
        id: "live_conn",
        provider: :google,
        profile: :user,
        tenant_id: "live_tenant",
        owner_type: :app_user,
        owner_id: "live_user",
        status: :connected,
        scopes: [@readonly_scope]
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "live_tenant",
        actor: %{id: "live_user", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "live_conn",
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: token},
        scopes: [@readonly_scope]
      })

    Connect.invoke(Meet.integration(), action_id, input,
      context: context,
      credential_lease: lease
    )
  end
end
