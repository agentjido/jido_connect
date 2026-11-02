defmodule Jido.Connect.Google.Calendar.TestSupport.LiveCalendar do
  @moduledoc false

  # Runs Calendar actions and the event poll through `Jido.Connect` with a
  # connection and a credential lease around a live access token, so live
  # smoke tests exercise the DSL, the scope check and the handlers, not only
  # the client. The declared scopes gate the runtime check; the token itself
  # may carry broader Google scopes.

  alias Jido.Connect
  alias Jido.Connect.Error
  alias Jido.Connect.Google.Calendar
  alias Jido.Connect.Google.Calendar.Client
  alias Jido.Connect.TestSupport.LiveSmoke

  @events_readonly_scope "https://www.googleapis.com/auth/calendar.events.readonly"
  @events_scope "https://www.googleapis.com/auth/calendar.events"

  # htmlLink carries the event ID and the calendar owner's address in Base64,
  # which the sanitizer does not decode. Meet entry points carry dial-in PINs,
  # also inside the `more` link, so their `uri` goes too; hangoutLink stays.
  @record_fields ["htmlLink", "pin", "uri"]
  @req_options {:jido_connect_google, :google_req_options}

  def events_readonly_scope, do: @events_readonly_scope
  def events_scope, do: @events_scope

  @doc """
  Records the Calendar responses of the current test under `name`.

  Each call starts the numbering again, so the next response goes to
  `name.json` and replaces what an earlier call under `name` wrote.
  """
  def record(name) do
    LiveSmoke.record(@req_options, :google_calendar, name, fields: @record_fields)
  end

  @doc """
  Keeps the following responses of the current test out of the fixtures
  until the next `record/1`, for setup writes that are not under test.

  The recorder has no pause, so while recording these responses go to a
  scratch directory that is removed when the test exits.
  """
  def skip_recording do
    if LiveSmoke.recording?() do
      root = Path.join(System.tmp_dir!(), "jido_connect_google_calendar_unrecorded")
      ExUnit.Callbacks.on_exit({__MODULE__, :scratch}, fn -> File.rm_rf!(root) end)

      LiveSmoke.record(@req_options, :google_calendar, "setup",
        fields: @record_fields,
        root: root
      )
    end

    :ok
  end

  @doc "Invokes a Calendar action with `scopes` on both the connection and the lease."
  def invoke(action_id, input, access_token, scopes) do
    {context, lease} = context_and_lease(access_token, scopes)

    Connect.invoke(Calendar.integration(), action_id, input,
      context: context,
      credential_lease: lease
    )
  end

  @doc "Runs `google.calendar.event.changed` once under the trigger's read-only scope."
  def poll(config, checkpoint, access_token) do
    {context, lease} = context_and_lease(access_token, [@events_readonly_scope])

    Connect.poll(Calendar.integration(), "google.calendar.event.changed", config,
      context: context,
      credential_lease: lease,
      checkpoint: checkpoint
    )
  end

  defp context_and_lease(access_token, scopes) do
    connection =
      Connect.Connection.new!(%{
        id: "live-calendar",
        provider: :google,
        profile: :user,
        tenant_id: "live",
        owner_type: :app_user,
        owner_id: "live-test-user",
        status: :connected,
        scopes: scopes
      })

    context =
      Connect.Context.new!(%{
        tenant_id: "live",
        actor: %{id: "live-test-user", type: :user},
        connection: connection
      })

    lease =
      Connect.CredentialLease.new!(%{
        connection_id: connection.id,
        provider: :google,
        profile: :user,
        expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
        fields: %{access_token: access_token},
        scopes: scopes
      })

    {context, lease}
  end

  @doc "Returns a per-run suffix in base32hex, the alphabet of Calendar event IDs."
  def run_id do
    5
    |> :crypto.strong_rand_bytes()
    |> Base.hex_encode32(case: :lower, padding: false)
  end

  @doc """
  Deletes an event a test may have left, without notifications.

  An event that is already gone, 404 or 410, counts as deleted. Any other
  failure raises with the event ID, so a cleanup that leaves an event behind
  fails the test.
  """
  def delete_leftover(calendar_id, event_id, access_token) do
    case Client.delete_event(
           %{calendar_id: calendar_id, event_id: event_id, send_updates: "none"},
           access_token
         ) do
      {:ok, _deleted} ->
        :ok

      {:error, %Error.ProviderError{status: status}} when status in [404, 410] ->
        :ok

      {:error, error} ->
        raise "cleanup could not delete live event #{event_id}: #{failure(error)}"
    end
  end

  # Names the failure without the error details, which may carry the response body.
  defp failure(%Error.ProviderError{status: status}) when is_integer(status), do: "HTTP #{status}"
  defp failure(%Error.ProviderError{reason: reason}), do: inspect(reason)
  defp failure(%{__struct__: module}), do: inspect(module)
  defp failure(_error), do: "unexpected error"
end
