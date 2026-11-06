defmodule Jido.Connect.Tempo.CreateWorklogActionTest do
  use ExUnit.Case, async: false

  # `tempo.worklog.create` through prepare/4 and commit/4, invoke/4 and the
  # generated Jido action, against the POST answers that the live tests
  # recorded on 2026-11-02: `worklog_create` (the 200 for worklog 79177 on
  # 2026-10-29, 08:15:00, 3661 seconds, issue 46097) and `worklog_create.3`
  # (the 403 for the same booking in the approved August period), and on
  # 2026-11-06, while Tempo required four work attributes:
  # `worklog_create_attributes` (the 200 for worklog 79267 on 2026-10-27,
  # without start time, 1800 seconds, a description of 858 bytes and a
  # value for each required attribute), `worklog_create_invalid_attribute`
  # (the 404 for an unknown account key) and `worklog_create_oauth` (the 200
  # for worklog 79268, booked through the OAuth access token). The sanitizer
  # recorded the test user as `account-1`.

  import ExUnit.CaptureLog

  alias Jido.Connect
  alias Jido.Connect.{Connection, Context, CredentialLease, Error, PreparedAction}
  alias Jido.Connect.Tempo
  alias Jido.Connect.Tempo.{Fixture, ScopeResolver}

  @action "tempo.worklog.create"
  @account "account-1"
  @api_token "tempo-api-token-275-secret"
  @access_token "tempo-oauth-token-275-secret"
  @marker "JCL live create test"
  @write ["tempo.worklogs.write"]

  # The values of the recorded attribute bookings as they were sent: the
  # stored value of the label build of `_JclPhase_` in that window,
  # `"true"`, `"1.5"` and the account key.
  @build "891b3db6-c452-456c-ae2c-7b53a06899fd"
  @attributes [
    %{key: "_JclAccount_", value: "JCL-PROJECT"},
    %{key: "_JclPhase_", value: @build},
    %{key: "_JclBillable_", value: "true"},
    %{key: "_JclHours_", value: "1.5"}
  ]
  # Tempo returned them in this order.
  @returned [
    %{key: "_JclPhase_", value: @build},
    %{key: "_JclHours_", value: "1.5"},
    %{key: "_JclBillable_", value: "true"},
    %{key: "_JclAccount_", value: "JCL-PROJECT"}
  ]
  @unknown_account "JCL-UNKNOWN"

  @input %{
    author_account_id: @account,
    issue_id: 46_097,
    start_date: "2026-10-29",
    start_time: "08:15:00",
    time_spent_seconds: 3661,
    description: @marker
  }

  defmodule RecordingClient do
    @moduledoc false

    # A provider client that reports its call instead of posting.
    def create_worklog(request, attrs) do
      send(self(), {:create_worklog, request.account_id, attrs})
      {:error, Jido.Connect.Error.provider("not posted", provider: :tempo)}
    end
  end

  setup {Req.Test, :verify_on_exit!}

  setup do
    put_env(:jido_connect_tempo, :tempo_req_options, plug: {Req.Test, __MODULE__})
    test_pid = self()

    Req.Test.stub(__MODULE__, fn conn ->
      send(test_pid, :posted)
      Fixture.respond(conn, "worklog_create")
    end)

    :ok
  end

  describe "confirmation" do
    test "prepare sends no request and returns a preview without the description" do
      context = context(:api_token)

      assert {:ok, %PreparedAction{} = prepared} =
               Connect.prepare(Tempo, @action, @input,
                 context: context,
                 credential_lease: lease(context)
               )

      refute_received :posted
      assert prepared.confirmation == :always
      assert prepared.confirmation_required? == true
      assert prepared.risk == :write

      # The core sanitizes the provider part of a preview into string keys.
      assert Map.take(prepared.preview, [
               "operation",
               "issue_id",
               "start_date",
               "start_time",
               "time_spent_seconds",
               "billable_seconds",
               "description_bytes",
               "attribute_count"
             ]) == %{
               "operation" => "create",
               "issue_id" => 46_097,
               "start_date" => "2026-10-29",
               "start_time" => "08:15:00",
               "time_spent_seconds" => 3661,
               "billable_seconds" => nil,
               "description_bytes" => 20,
               "attribute_count" => 0
             }

      refute inspect(prepared) =~ @marker
      refute inspect(prepared) =~ @api_token
    end

    test "a direct call fails with direct_mutation_mode: :deny" do
      context = context(:api_token)

      assert {:error, %Error.AuthError{reason: :execution_authorization_required}} =
               Connect.invoke(Tempo, @action, @input,
                 context: context,
                 credential_lease: lease(context),
                 direct_mutation_mode: :deny
               )

      refute_received :posted
    end

    test "a host configured with direct_mutation_mode: :deny also stops the generated action" do
      put_env(:jido_connect, :direct_mutation_mode, :deny)
      context = context(:oauth2_user)

      assert {:error, %Error.AuthError{reason: :execution_authorization_required}} =
               Tempo.Actions.CreateWorklog.run(@input, %{
                 integration_context: context,
                 credential_lease: lease(context)
               })

      refute_received :posted
    end

    test "a commit without host evidence or with a changed payload fails before POST" do
      context = context(:api_token)
      {:ok, prepared} = prepare(context, @input)

      assert {:error, %Error.AuthError{reason: :execution_authorization_required}} =
               Connect.commit(Tempo, prepared, @input,
                 context: context,
                 credential_lease: lease(context)
               )

      assert {:error, %Error.AuthError{reason: :execution_authorization_required}} =
               commit(context, prepared, @input, execution_authorization: true)

      for changed <- [
            %{@input | time_spent_seconds: 3662},
            %{@input | start_date: "2026-10-30"},
            Map.put(@input, :billable_seconds, 0),
            Map.delete(@input, :description)
          ] do
        assert {:error, %Error.AuthError{reason: :prepared_action_stale}} =
                 commit(context, prepared, changed)
      end

      refute_received :posted
    end

    test "an authorized commit sends exactly one POST and returns the confirmed worklog" do
      context = context(:api_token)
      {:ok, prepared} = prepare(context, @input)

      assert {:ok, %{worklog: worklog} = result} = commit(context, prepared, @input)

      assert_received :posted
      refute_received :posted

      assert %{
               tempo_worklog_id: 79_177,
               author_account_id: @account,
               start_date: "2026-10-29",
               start_time: "08:15:00",
               time_spent_seconds: 3661,
               billable_seconds: 3661,
               issue_id: 46_097,
               description: @marker,
               work_attributes: []
             } = worklog

      assert Map.keys(result) == [:worklog]
      assert {:ok, _json} = Jason.encode(result)
    end

    # The recorded attribute booking with the input it was sent with.
    test "the result keeps the full description and the attribute values" do
      description = Fixture.recorded!("worklog_create_attributes")["body"]["description"]
      Req.Test.stub(__MODULE__, &Fixture.respond(&1, "worklog_create_attributes"))

      input = %{
        author_account_id: @account,
        issue_id: 46_097,
        start_date: "2026-10-27",
        time_spent_seconds: 1800,
        description: description,
        attributes: @attributes
      }

      context = context(:api_token)
      {:ok, prepared} = prepare(context, input)

      assert prepared.preview["description_bytes"] == 858
      assert prepared.preview["attribute_count"] == 4
      refute inspect(prepared.preview) =~ "JCL-PROJECT"
      refute inspect(prepared.preview) =~ @build

      assert {:ok, %{worklog: %{description: ^description} = worklog}} =
               commit(context, prepared, input)

      assert {worklog.work_attributes, worklog.start_time} == {@returned, "00:00:00"}
    end
  end

  describe "checks before POST" do
    test "an issue key and zero or fractional seconds fail input validation" do
      context = context(:api_token)

      for input <- [
            %{@input | issue_id: "PROJ-123"},
            %{@input | time_spent_seconds: 0},
            %{@input | time_spent_seconds: 5400.5},
            Map.put(@input, :billable_seconds, -1),
            Map.put(@input, :bypass_period_closures_and_approvals, true),
            Map.put(@input, :remaining_estimate_seconds, 0)
          ] do
        assert {:error, %Error.ValidationError{reason: :input}} = prepare(context, input)
      end

      refute_received :posted
    end

    test "an invalid date or time, duplicate attribute keys and a foreign author fail at prepare" do
      context = context(:api_token)

      for {input, error} <- invalid_inputs() do
        assert {:error, ^error} = prepare(context, input) |> reason()
      end

      refute_received :posted
    end

    test "a connection without subject.account_id prepares but fails at commit before POST" do
      context = context(:api_token, account_id: nil)
      {:ok, prepared} = prepare(context, @input)

      assert {:error, %Error.AuthError{reason: :tempo_account_id_required}} =
               commit(context, prepared, @input)

      refute_received :posted
    end

    # invoke/4 with direct calls allowed skips the preview, so this reaches
    # the handler; the core logs its deprecation warning for each call.
    test "the handler checks the same input before it resolves the provider client" do
      context = context(:api_token)

      capture_log(fn ->
        for {input, error} <- invalid_inputs() do
          assert {:error, ^error} =
                   Connect.invoke(Tempo, @action, input,
                     context: context,
                     credential_lease: lease(context),
                     direct_mutation_mode: :allow,
                     provider_client: RecordingClient
                   )
                   |> reason()
        end
      end)

      refute_received {:create_worklog, _account_id, _attrs}
      refute_received :posted
    end
  end

  describe "authorization gates" do
    test "a missing or read-only grant stops prepare and commit before POST" do
      for scopes <- [[], ["tempo.worklogs.read"], ScopeResolver.granted_labels("read")] do
        context = context(:api_token, scopes: scopes)

        assert {:error,
                %Error.AuthError{
                  reason: :missing_scopes,
                  missing_scopes: ["tempo.worklogs.write"]
                }} =
                 prepare(context, @input)
      end

      {:ok, prepared} = prepare(context(:api_token), @input)
      read_only = context(:api_token, scopes: ["tempo.worklogs.read"])

      assert {:error, %Error.AuthError{reason: :missing_scopes}} =
               commit(read_only, prepared, @input)

      refute_received :posted
    end

    # The recorded token response with only `scope` changed to the coarse
    # grants of Tempo's OpenAPI example; the host records granted_labels/1.
    # This stays derived: the token responses of the test site never held
    # a coarse grant (see the next test).
    test "a recorded OAuth token with scope read write may create, one with read only may not" do
      for {scope, outcome} <- [{"read write", :posted}, {"read", :missing_scopes}] do
        token = put_in(Fixture.recorded!("oauth_exchange")["body"], ["scope"], scope)
        context = context(:oauth2_user, scopes: ScopeResolver.granted_labels(token["scope"]))

        case outcome do
          :posted ->
            {:ok, prepared} = prepare(context, @input)

            assert {:ok, %{worklog: %{tempo_worklog_id: 79_177}}} =
                     commit(context, prepared, @input)

            assert_received :posted

          :missing_scopes ->
            assert {:error, %Error.AuthError{reason: :missing_scopes}} = prepare(context, @input)
            refute_received :posted
        end
      end
    end

    # The recorded OAuth booking on a connection whose labels come from the
    # scope that the stored token pair was issued with, recorded in
    # `oauth_refresh`: `worklogs:manage` grants the write label.
    test "the recorded OAuth booking commits with the labels of the recorded token scope" do
      scope = Fixture.recorded!("oauth_refresh")["body"]["scope"]
      grants = Jido.Connect.Scope.parse(scope)
      assert "worklogs:manage" in grants
      refute Enum.any?(["read", "write"], &(&1 in grants))

      test_pid = self()

      Req.Test.stub(__MODULE__, fn conn ->
        send(test_pid, :posted)
        Fixture.respond(conn, "worklog_create_oauth")
      end)

      input = %{
        author_account_id: @account,
        issue_id: 46_097,
        start_date: "2026-10-27",
        start_time: "10:30:00",
        time_spent_seconds: 900,
        description: "JCL live OAuth booking",
        attributes: @attributes
      }

      context = context(:oauth2_user, scopes: ScopeResolver.granted_labels(scope))
      {:ok, prepared} = prepare(context, input)

      assert {:ok, %{worklog: worklog}} = commit(context, prepared, input)
      assert_received :posted
      refute_received :posted

      assert %{
               tempo_worklog_id: 79_268,
               start_date: "2026-10-27",
               start_time: "10:30:00",
               time_spent_seconds: 900,
               billable_seconds: 900,
               description: "JCL live OAuth booking",
               work_attributes: @returned
             } = worklog
    end

    test "an expired lease, a lease of another connection or without the token stops the call" do
      context = context(:api_token)
      {:ok, prepared} = prepare(context, @input)

      for lease <- [
            lease(context, expires_at: DateTime.add(DateTime.utc_now(), -1, :second)),
            lease(context(:api_token, connection_id: "tempo_conn_other")),
            lease(context, fields: %{access_token: @access_token})
          ] do
        assert {:error, %Error.AuthError{}} =
                 commit(context, prepared, @input, credential_lease: lease)
      end

      refute_received :posted
    end

    test "a denying host policy stops prepare and commit before POST" do
      context = context(:api_token)
      deny = fn _operation, _input, _context, _connection -> {:deny, :not_your_timesheet} end

      assert {:error, %Error.AuthError{reason: :policy_denied}} =
               prepare(context, @input, policy: deny)

      {:ok, prepared} = prepare(context, @input)

      assert {:error, %Error.AuthError{reason: :policy_denied}} =
               commit(context, prepared, @input, policy: deny)

      refute_received :posted
    end
  end

  describe "privacy" do
    test "logs, telemetry and errors hold no token, description or attribute value" do
      handler = "tempo-create-#{System.unique_integer([:positive])}"
      test_pid = self()

      :telemetry.attach_many(
        handler,
        for(
          op <- [:invoke, :prepare, :commit],
          phase <- [:start, :stop, :exception],
          do: [:jido, :connect, op, phase]
        ),
        fn event, measurements, metadata, _config ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler) end)

      # The recorded 404 for an unknown account key with an echo of the
      # description and the attribute value appended. Tempo's recorded text,
      # `Account not found`, quotes neither, so the echo is derived from the
      # recorded `Non valid time '25:00:00'`.
      input =
        Map.put(
          @input,
          :attributes,
          Enum.map(@attributes, fn
            %{key: "_JclAccount_"} = attribute -> %{attribute | value: @unknown_account}
            attribute -> attribute
          end)
        )

      Req.Test.stub(__MODULE__, fn conn ->
        Fixture.respond(conn, "worklog_create_invalid_attribute",
          body:
            &update_in(&1, ["errors"], fn errors ->
              errors ++
                [
                  %{"message" => "Non valid description '#{@marker}'"},
                  %{
                    "message" =>
                      "Non valid value '#{@unknown_account}' for work attribute '_JclAccount_'"
                  }
                ]
            end)
        )
      end)

      context = context(:api_token)

      log =
        capture_log(fn ->
          {:ok, prepared} = prepare(context, input)

          assert {:error, %Error.ProviderError{reason: :not_found, status: 404} = error} =
                   commit(context, prepared, input)

          send(test_pid, {:error, error})

          assert {:error, %Error.ProviderError{}} =
                   Connect.invoke(Tempo, @action, input,
                     context: context,
                     credential_lease: lease(context),
                     direct_mutation_mode: :allow
                   )
        end)

      assert_received {:error, error}
      events = collect_telemetry([])
      assert length(events) >= 6
      assert log =~ "Direct mutation invocation is deprecated"

      for text <- [log, inspect(events), inspect(error), inspect(Error.to_map(error))],
          secret <- [@api_token, @marker, @unknown_account, @build] do
        refute text =~ secret
      end
    end
  end

  defp invalid_inputs do
    [
      {%{@input | start_date: "2026-02-30"}, {:invalid_worklog_input, :start_date}},
      {%{@input | start_date: "29.10.2026"}, {:invalid_worklog_input, :start_date}},
      {%{@input | start_time: "25:00:00"}, {:invalid_worklog_input, :start_time}},
      {%{@input | start_time: "08:15"}, {:invalid_worklog_input, :start_time}},
      {Map.put(@input, :attributes, [
         %{"key" => "_Phase_", "value" => "build"},
         %{"key" => "_Phase_", "value" => "test"}
       ]), {:invalid_worklog_input, :attributes}},
      {%{@input | author_account_id: "account-2"}, {:foreign_worklog_author, :author_account_id}}
    ]
  end

  defp reason({:error, %Error.ValidationError{reason: reason, subject: subject}}),
    do: {:error, {reason, subject}}

  defp reason({:error, %Error.AuthError{reason: reason, details: %{field: field}}}),
    do: {:error, {reason, field}}

  defp reason(other), do: other

  defp collect_telemetry(events) do
    receive do
      {:telemetry, event, measurements, metadata} ->
        collect_telemetry([{event, measurements, metadata} | events])
    after
      0 -> Enum.reverse(events)
    end
  end

  defp prepare(context, input, opts \\ []) do
    Connect.prepare(
      Tempo,
      @action,
      input,
      [context: context, credential_lease: lease(context)] ++ opts
    )
  end

  defp commit(context, prepared, input, opts \\ []) do
    Connect.commit(
      Tempo,
      prepared,
      input,
      Keyword.merge(
        [
          context: context,
          credential_lease: lease(context),
          execution_authorization: %{prepared_action_id: prepared.id},
          authorization_validator: fn evidence, prepared, _context ->
            evidence == %{prepared_action_id: prepared.id}
          end
        ],
        opts
      )
    )
  end

  defp context(profile, opts \\ []) do
    connection =
      Connection.new!(%{
        id: Keyword.get(opts, :connection_id, "tempo_conn_1"),
        provider: :tempo,
        profile: profile,
        tenant_id: "tenant_1",
        owner_type: :app_user,
        owner_id: "user_1",
        subject: %{account_id: Keyword.get(opts, :account_id, @account)},
        status: :connected,
        scopes: Keyword.get(opts, :scopes, @write),
        metadata: %{api_origin: "https://api.us.tempo.io"}
      })

    Context.new!(%{
      tenant_id: "tenant_1",
      actor: %{id: "user_1", type: :app_user},
      connection: connection
    })
  end

  # One fixed expiry per connection, so prepare and commit see the same lease.
  defp lease(%Context{connection: connection}, opts \\ []) do
    fields =
      Keyword.get_lazy(opts, :fields, fn ->
        case connection.profile do
          :api_token -> %{api_token: @api_token}
          :oauth2_user -> %{access_token: @access_token}
        end
      end)

    CredentialLease.from_connection!(connection, fields,
      issued_at: ~U[2026-11-02 18:00:00Z],
      expires_at: Keyword.get(opts, :expires_at, ~U[2099-01-01 00:00:00Z])
    )
  end

  defp put_env(app, key, value) do
    previous = Application.fetch_env(app, key)
    Application.put_env(app, key, value)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(app, key, value)
        :error -> Application.delete_env(app, key)
      end
    end)
  end
end
