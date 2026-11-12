defmodule Jido.Connect.Google.Calendar.EventChangedPollerTest do
  @moduledoc """
  Polls `google.calendar.event.changed` through `Jido.Connect.poll/4` and the
  real Calendar client against `Req.Test`, replaying responses recorded from
  the Google Workspace test account.

  Where a test changes a recorded response, a comment names the change.
  """

  use ExUnit.Case, async: false

  alias Jido.Connect
  alias Jido.Connect.Error.ProviderError
  alias Jido.Connect.Google.Calendar
  alias Jido.Connect.TestSupport.LiveSmoke

  @trigger_id "google.calendar.event.changed"
  @calendar_id "primary"
  @events_path "/v3/calendars/primary/events"

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(
      :jido_connect_google_calendar,
      :google_calendar_api_base_url,
      "https://calendar.test"
    )

    Application.put_env(:jido_connect_google, :google_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:jido_connect_google_calendar, :google_calendar_api_base_url)
      Application.delete_env(:jido_connect_google, :google_req_options)
    end)
  end

  describe "requests" do
    test "an initializing poll asks for deleted events without a sync token" do
      page = recorded("event_changed_init")

      expect_page(page, fn params ->
        assert params["showDeleted"] == "true"
        refute Map.has_key?(params, "syncToken")
        refute Map.has_key?(params, "pageToken")
      end)

      assert {:ok, %{signals: [], checkpoint: checkpoint}} =
               poll(%{calendar_id: @calendar_id}, nil)

      assert checkpoint == page["nextSyncToken"]
    end

    test "an incremental poll sends its sync token on every page" do
      first = recorded("event_changed_paged")
      last = recorded("event_changed_paged.2")

      expect_page(first, fn params ->
        assert params["syncToken"] == "sync-1"
        assert params["showDeleted"] == "true"
        assert params["maxResults"] == "2"
        refute Map.has_key?(params, "pageToken")
      end)

      expect_page(last, fn params ->
        assert params["pageToken"] == first["nextPageToken"]
        assert params["syncToken"] == "sync-1"
        assert params["showDeleted"] == "true"
      end)

      assert {:ok, %{signals: signals, checkpoint: checkpoint}} =
               poll(%{calendar_id: @calendar_id, page_size: 2}, "sync-1")

      assert Enum.map(signals, & &1.event_id) ==
               Enum.map(first["items"] ++ last["items"], & &1["id"])

      assert Enum.all?(signals, &(&1.change_type == "updated"))
      assert checkpoint == last["nextSyncToken"]
    end
  end

  describe "recurring events with single_events: false" do
    test "emit the series master with its recurrence and the exception with its origin" do
      # The recorded unexpanded full sync, the one recording with a moved
      # exception, replayed as an incremental page: both answers carry items
      # and a nextSyncToken.
      page = recorded("event_cancelled_init_unexpanded")

      # The weekly series of the test calendar has six Monday occurrences
      # from 2026-11-09 08:00 Berlin; its second one, the only moved
      # occurrence in the recording, starts at 09:00.
      assert [%{"id" => exception_id, "recurringEventId" => master_id}] =
               Enum.filter(page["items"], &moved?/1)

      expect_page(page, fn params ->
        assert params["singleEvents"] == "false"
        assert params["syncToken"] == "sync-1"
      end)

      assert {:ok, %{signals: signals, checkpoint: checkpoint}} =
               poll(%{calendar_id: @calendar_id, single_events: false}, "sync-1")

      assert checkpoint == page["nextSyncToken"]

      master = signal!(signals, master_id)
      assert master.change_type == "updated"
      assert master.event.recurrence == ["RRULE:FREQ=WEEKLY;COUNT=6;BYDAY=MO"]
      assert master.event.recurring_event_id == nil

      exception = signal!(signals, exception_id)
      assert exception.change_type == "updated"
      assert exception.start == "2026-11-16T09:00:00+01:00"
      assert exception.event.recurring_event_id == master_id
      assert exception.event.original_start == "2026-11-16T08:00:00+01:00"
      assert exception.event.recurrence == []
    end
  end

  describe "failures" do
    test "an initializing poll whose final page lacks nextSyncToken fails" do
      # Derived: the recorded full sync with its nextSyncToken removed.
      page = "event_changed_init" |> recorded() |> Map.delete("nextSyncToken")

      expect_page(page, fn _params -> :ok end)

      assert {:error,
              %ProviderError{
                reason: :invalid_response,
                details: %{
                  checkpoint_reset: %{
                    action: :clear_checkpoint,
                    behavior: :initialize_without_replay
                  }
                }
              }} = poll(%{calendar_id: @calendar_id}, nil)
    end

    test "an incremental poll whose final page lacks nextSyncToken fails instead of keeping its checkpoint" do
      # Derived: the second recorded page with its nextSyncToken removed.
      last = "event_changed_paged.2" |> recorded() |> Map.delete("nextSyncToken")

      expect_page(recorded("event_changed_paged"), fn _params -> :ok end)
      expect_page(last, fn _params -> :ok end)

      assert {:error,
              %ProviderError{
                reason: :invalid_response,
                details: %{
                  checkpoint_reset: %{
                    action: :clear_checkpoint,
                    behavior: :initialize_without_replay
                  }
                }
              }} = poll(%{calendar_id: @calendar_id, page_size: 2}, "sync-1")
    end

    test "a later page answered with HTTP 500 returns the provider error and no checkpoint" do
      # One answer per request, so Req's retry of server errors stays off.
      Application.put_env(:jido_connect_google, :google_req_options,
        plug: {Req.Test, __MODULE__},
        retry: false
      )

      expect_page(recorded("event_changed_paged"), fn _params -> :ok end)

      # Derived: the second recorded page with its status 200 replaced by 500.
      Req.Test.expect(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(recorded("event_changed_paged.2"))
      end)

      assert {:error, %ProviderError{provider: :google, status: 500} = error} =
               poll(%{calendar_id: @calendar_id, page_size: 2}, "sync-1")

      refute error.reason == :checkpoint_expired
    end
  end

  describe "cancellations" do
    test "an item with only id and status emits a cancellation without an event read" do
      # Derived: the recorded cancelled item reduced to id and status; Google
      # returned it with all its fields.
      page = recorded("event_changed_cancelled")
      [cancelled] = page["items"]
      tombstone = Map.take(cancelled, ["id", "status"])

      # One expectation: an events.get request would find none and fail.
      expect_page(Map.put(page, "items", [tombstone]), fn _params -> :ok end)

      assert {:ok, %{signals: [signal], checkpoint: checkpoint}} =
               poll(%{calendar_id: @calendar_id}, "sync-1")

      assert checkpoint == page["nextSyncToken"]

      assert %{
               event_id: event_id,
               calendar_id: @calendar_id,
               status: "cancelled",
               change_type: "cancelled"
             } = signal

      assert event_id == cancelled["id"]

      assert signal |> Map.keys() |> Enum.sort() == [
               :calendar_id,
               :change_type,
               :event,
               :event_id,
               :status
             ]
    end

    test "a cancelled occurrence keeps its series and original start" do
      # The second of three weekly occurrences from 2027-01-11 08:00 Berlin,
      # cancelled; the other two are unchanged.
      page = recorded("event_cancelled_occurrence")

      assert [%{"id" => occurrence_id, "recurringEventId" => series_id}] =
               Enum.filter(page["items"], &(&1["status"] == "cancelled"))

      expect_page(page, fn _params -> :ok end)

      assert {:ok, %{signals: signals}} = poll(%{calendar_id: @calendar_id}, "sync-1")

      occurrence = signal!(signals, occurrence_id)
      assert occurrence.change_type == "cancelled"
      assert occurrence.event.recurring_event_id == series_id
      assert occurrence.event.original_start == "2027-01-18T08:00:00+01:00"
    end

    test "a cancelled series master without times gets no start, end or occurrence data" do
      # Derived: the recorded cancelled master with start and end removed;
      # Google returned it with its times.
      page = recorded("event_cancelled_series_unexpanded")
      assert [%{"id" => master_id}] = Enum.filter(page["items"], &Map.has_key?(&1, "recurrence"))

      items =
        Enum.map(page["items"], fn
          %{"id" => ^master_id} = master -> Map.drop(master, ["start", "end"])
          item -> item
        end)

      expect_page(Map.put(page, "items", items), fn params ->
        assert params["singleEvents"] == "false"
      end)

      assert {:ok, %{signals: signals}} =
               poll(%{calendar_id: @calendar_id, single_events: false}, "sync-1")

      master = signal!(signals, master_id)
      assert master.change_type == "cancelled"
      refute Map.has_key?(master, :start)
      refute Map.has_key?(master, :end)
      assert master.event.original_start == nil
      assert master.event.recurring_event_id == nil
    end
  end

  describe "attendee responses" do
    test "a confirmed event the user declined is an update that keeps the decline" do
      page = recorded("event_changed_declined")
      [declined] = page["items"]
      expect_page(page, fn _params -> :ok end)

      assert {:ok, %{signals: [signal]}} = poll(%{calendar_id: @calendar_id}, "sync-1")

      assert signal.event_id == declined["id"]
      assert signal.status == "confirmed"
      assert signal.change_type == "updated"

      assert [%{self?: true, response_status: "declined"}] =
               Enum.filter(signal.event.attendees, & &1.self?)
    end
  end

  defp recorded(name), do: LiveSmoke.fixture!(:google_calendar, name)

  # Expects one events.list request, checks its query with `check` and
  # answers with `body`.
  defp expect_page(body, check) do
    Req.Test.expect(__MODULE__, fn conn ->
      assert conn.method == "GET"
      assert conn.request_path == @events_path
      check.(conn.query_params)
      Req.Test.json(conn, body)
    end)
  end

  # An occurrence moved away from its place in the series.
  defp moved?(item) do
    Map.has_key?(item, "recurringEventId") and
      get_in(item, ["start", "dateTime"]) != get_in(item, ["originalStartTime", "dateTime"])
  end

  defp signal!(signals, event_id) do
    assert [signal] = Enum.filter(signals, &(&1.event_id == event_id))
    signal
  end

  defp poll(config, checkpoint) do
    {context, lease} = context_and_lease()

    Connect.poll(Calendar.integration(), @trigger_id, config,
      context: context,
      credential_lease: lease,
      checkpoint: checkpoint
    )
  end

  defp context_and_lease do
    scopes = ["https://www.googleapis.com/auth/calendar.events.readonly"]

    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :google,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "tenant_1",
        actor: %{id: "user_1", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: "conn_1",
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: "token"},
        scopes: scopes
      })

    {context, lease}
  end
end
