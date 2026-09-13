defmodule Jido.Connect.TelemetryTest do
  use ExUnit.Case, async: false

  alias Jido.Connect

  defmodule Handler do
    def run(_input, _context), do: {:ok, %{}}
  end

  def handle_event(event, measurements, metadata, pid) do
    send(pid, {:telemetry, event, measurements, metadata})
  end

  test "invoke emits sanitized start and stop telemetry" do
    attach_telemetry([:invoke])

    {context, lease} = context_and_lease()

    assert {:ok, %{}} =
             Connect.invoke(spec(), "demo.action", %{},
               context: context,
               credential_lease: lease
             )

    assert_receive {:telemetry, [:jido, :connect, :invoke, :start], %{system_time: system_time},
                    start_metadata}

    assert is_integer(system_time)
    assert start_metadata.integration_id == :demo
    assert start_metadata.operation_id == "demo.action"
    assert start_metadata.tenant_id == "tenant_1"
    assert start_metadata.actor_type == :user
    assert start_metadata.connection_id == "conn_1"
    assert start_metadata.auth_profile == :user
    assert start_metadata.credential_lease_connection_id == "conn_1"
    refute inspect(start_metadata) =~ "secret-token"

    assert_receive {:telemetry, [:jido, :connect, :invoke, :stop], %{duration: duration},
                    stop_metadata}

    assert is_integer(duration)
    assert duration >= 0
    assert stop_metadata.integration_id == :demo
    assert stop_metadata.operation_id == "demo.action"
    assert stop_metadata.status == :ok
    assert stop_metadata.connection_id == "conn_1"
    refute inspect(stop_metadata) =~ "secret-token"
  end

  test "invoke stop telemetry includes normalized error metadata" do
    attach_telemetry([:invoke])

    {context, _lease} = context_and_lease()

    assert {:error, %Connect.Error.AuthError{reason: :credential_lease_required}} =
             Connect.invoke(spec(), "demo.action", %{}, context: context)

    assert_receive {:telemetry, [:jido, :connect, :invoke, :start], _measurements, _metadata}

    assert_receive {:telemetry, [:jido, :connect, :invoke, :stop], %{duration: duration},
                    %{
                      integration_id: :demo,
                      operation_id: "demo.action",
                      status: :error,
                      error_type: :auth_error,
                      error_class: :auth,
                      error_reason: :credential_lease_required,
                      retryable?: false
                    }}

    assert is_integer(duration)
    assert duration >= 0
  end

  test "poll emits telemetry for the poll execution boundary" do
    attach_telemetry([:poll])

    assert {:error, %Connect.Error.ValidationError{reason: :unknown_trigger}} =
             Connect.poll(spec(), "demo.missing", %{})

    assert_receive {:telemetry, [:jido, :connect, :poll, :start], _measurements,
                    %{integration_id: :demo, operation_id: "demo.missing"}}

    assert_receive {:telemetry, [:jido, :connect, :poll, :stop], _measurements,
                    %{
                      integration_id: :demo,
                      operation_id: "demo.missing",
                      status: :error,
                      error_type: :validation_error,
                      error_class: :invalid,
                      error_reason: :unknown_trigger
                    }}
  end

  test "exception telemetry does not expose callback arguments" do
    attach_telemetry([:invoke])
    secret = "telemetry-secret-#{System.unique_integer([:positive])}"

    assert_raise KeyError, fn ->
      Connect.Telemetry.span(:invoke, %{}, fn ->
        fetch_missing(Map.new(access_token: secret))
      end)
    end

    assert_receive {:telemetry, [:jido, :connect, :invoke, :start], _measurements, _metadata}
    assert_receive {:telemetry, [:jido, :connect, :invoke, :exception], _measurements, metadata}
    assert metadata.error_type == KeyError
    assert metadata.exception == "Jido Connect operation raised"
    assert metadata.stacktrace =~ "fetch_missing/1"
    refute inspect(metadata) =~ secret
  end

  defp fetch_missing(credentials), do: Map.fetch!(credentials, :missing_key)

  defp attach_telemetry(operations) do
    handler_id = "jido-connect-telemetry-test-#{System.unique_integer([:positive])}"

    events =
      for operation <- operations,
          phase <- [:start, :stop, :exception] do
        [:jido, :connect, operation, phase]
      end

    :ok =
      :telemetry.attach_many(
        handler_id,
        events,
        &__MODULE__.handle_event/4,
        self()
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  defp spec do
    Connect.Spec.new!(%{
      id: :demo,
      name: "Demo",
      auth_profiles: [
        Connect.AuthProfile.new!(%{
          id: :user,
          kind: :oauth2,
          owner: :user,
          subject: :user,
          label: "User",
          scopes: ["read"]
        })
      ],
      actions: [
        Connect.ActionSpec.new!(%{
          id: "demo.action",
          name: :demo_action,
          label: "Demo action",
          resource: :item,
          verb: :read,
          data_classification: :workspace_metadata,
          auth_profile: :user,
          handler: Handler,
          input_schema: Zoi.object(%{}),
          output_schema: Zoi.object(%{}),
          scopes: ["read"]
        })
      ],
      triggers: []
    })
  end

  defp context_and_lease do
    connection =
      Connect.Connection.new!(%{
        id: "conn_1",
        provider: :demo,
        profile: :user,
        tenant_id: "tenant_1",
        owner_type: :user,
        owner_id: "user_1",
        status: :connected,
        scopes: ["read"]
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
        expires_at: DateTime.add(DateTime.utc_now(), 60, :second),
        fields: %{access_token: "secret-token"}
      })

    {context, lease}
  end
end
