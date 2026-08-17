defmodule Jido.Connect.Things.Writer do
  @moduledoc """
  Guarded prepare and single-send commit runtime for Things Cloud writes.

  Prepare performs provider reads only. Commit rechecks the exact account,
  schema, provider head, input, plan, and update target before it sends one
  request. The writer does not retry a commit.
  """

  alias Jido.Connect.{Connection, Error, ExecutionSnapshot}

  alias Jido.Connect.Things.{
    ChangePlanner,
    Client,
    Identifier,
    Input,
    Protocol,
    ReadAdapter,
    Reader,
    State,
    Todo,
    WriteWire
  }

  defmodule Plan do
    @moduledoc false
    @enforce_keys [
      :action_id,
      :connection_id,
      :account_binding,
      :history_fingerprint,
      :ancestor_index,
      :schema,
      :operation_id,
      :operation_hash,
      :body_hash,
      :wire_timestamp,
      :wire_today,
      :expected_modified_at,
      :risk,
      :preview,
      :confirmation
    ]
    defstruct @enforce_keys

    def to_public_map(%__MODULE__{} = plan), do: Map.from_struct(plan)
  end

  @write_actions [
    "things.todo.create",
    "things.todo.update",
    "things.todo.schedule",
    "things.todo.deadline.set",
    "things.todo.deadline.clear",
    "things.todo.tags.set",
    "things.todo.move",
    "things.todo.complete",
    "things.todo.cancel",
    "things.todo.reopen",
    "things.todo.trash",
    "things.todo.restore"
  ]

  def prepare(action_id, input, client, connection, opts \\ [])

  def prepare(action_id, input, %Client{} = client, %Connection{} = connection, opts)
      when action_id in @write_actions do
    with {:ok, input} <- Input.parse(action_id, input),
         :ok <- Protocol.validate_endpoint(client),
         {:ok, account, history} <- Reader.snapshot(client),
         {:ok, planned, wire_timestamp, wire_today} <-
           prepare_operation(action_id, input, client, connection, account, history, opts) do
      operation = planned.operation

      plan = %Plan{
        action_id: action_id,
        connection_id: connection.id,
        account_binding: Protocol.account_binding(client),
        history_fingerprint: Protocol.history_fingerprint(account),
        ancestor_index: history.head,
        schema: history.schema,
        operation_id: operation.id,
        operation_hash: operation.operation_sha256,
        body_hash: operation.body_sha256,
        wire_timestamp: wire_timestamp,
        wire_today: wire_today,
        expected_modified_at: planned.expected_modified_at,
        risk: planned.risk,
        preview: planned.preview,
        confirmation: ""
      }

      {:ok, %{plan | confirmation: confirmation(plan)}}
    end
  end

  def prepare(action_id, _input, _client, _connection, _opts) do
    {:error, Error.unknown_action(action_id)}
  end

  def commit(%Plan{} = plan, input, %Client{} = client, %Connection{} = connection, opts \\ []) do
    with {:ok, input} <- Input.parse(plan.action_id, input),
         :ok <- require_commit_option(opts),
         :ok <- require_risk_gate(plan, opts),
         {:ok, operation} <- rebuild_operation(plan, input),
         :ok <- validate_plan(plan, operation, connection) do
      lock = option(opts, :lock) || (&local_account_lock/2)

      case lock.(plan.account_binding, fn ->
             preflight_and_commit(plan, input, operation, client, connection, opts)
           end) do
        :aborted ->
          protocol_error(:write_lock_unavailable)

        result ->
          result
      end
    end
  end

  defp prepare_operation(action_id, input, client, connection, account, history, opts) do
    wire_timestamp = timestamp(opts)
    wire_today = today(opts)
    id = if action_id == "things.todo.create", do: id_generator(opts).(), else: input.id

    with {:ok, state} <-
           planning_state(action_id, input, client, connection, account, history, opts),
         {:ok, planned} <-
           ChangePlanner.prepare(action_id, input, state,
             id: id,
             timestamp: wire_timestamp,
             today: wire_today
           ) do
      {:ok, planned, wire_timestamp, wire_today}
    end
  end

  defp planning_state("things.todo.create", input, client, _connection, account, history, _opts) do
    if Map.get(input, :tag_ids, []) == [] and
         Enum.all?([:area_id, :project_id, :heading_id], &(not Map.has_key?(input, &1))) do
      {:ok, empty_state(history.head)}
    else
      Reader.load_state(client, account, history)
    end
  end

  defp planning_state("things.todo.update", input, client, connection, account, history, opts) do
    case option(opts, :read_adapter) do
      nil ->
        Reader.load_state(client, account, history)

      adapter ->
        with {:ok, result} <- ReadAdapter.get(adapter, connection.id, input.id, history.head),
             :ok <- validate_adapter_head(result, history.head),
             {:ok, todo} <- normalize_adapter_todo(result) do
          {:ok, %{empty_state(history.head) | tasks: %{todo.id => todo}}}
        end
    end
  end

  defp planning_state(_action_id, _input, client, _connection, account, history, _opts),
    do: Reader.load_state(client, account, history)

  defp empty_state(head), do: %{State.new() | provider_head: head, last_server_index: head}

  defp validate_adapter_head(result, head) do
    observed = Map.get(result, :provider_head) || Map.get(result, "provider_head")

    if observed == head do
      :ok
    else
      protocol_error(:stale_read_adapter, %{expected_head: head, observed_head: observed})
    end
  end

  defp normalize_adapter_todo(result) do
    attrs = Map.get(result, :todo) || Map.get(result, "todo")

    case Todo.new(attrs) do
      {:ok, todo} -> {:ok, todo}
      {:error, _reason} -> protocol_error(:invalid_read_adapter_todo)
    end
  end

  defp preflight_and_commit(plan, input, operation, client, connection, opts) do
    with :ok <- Protocol.validate_endpoint(client),
         {:ok, account} <- Client.verify_account(client),
         :ok <- Protocol.validate_account(client, account),
         :ok <- validate_account_binding(plan, client, account),
         {:ok, history} <- Client.history(client, account.history_key),
         :ok <- Protocol.validate_history(history),
         :ok <- validate_fresh_head(plan, history),
         :ok <- recheck_plan(plan, input, operation, client, account, history),
         {:ok, server_head} <- post_once(client, account.history_key, plan, operation),
         verified <-
           verify(
             client,
             account.history_key,
             plan,
             operation,
             verification_attempts(opts),
             verification_delay(opts)
           ) do
      {:ok,
       %{
         receipt: %{
           action_id: plan.action_id,
           external_id: plan.operation_id,
           connection_id: connection.id,
           delivery: if(verified, do: "confirmed", else: "sent_unverified"),
           verified: verified,
           provider_head: server_head
         }
       }}
    end
  end

  defp recheck_plan(
         %Plan{action_id: "things.todo.create"},
         _input,
         _operation,
         _client,
         _account,
         _history
       ),
       do: :ok

  defp recheck_plan(plan, input, operation, client, account, history) do
    with {:ok, state} <- Reader.load_state(client, account, history),
         {:ok, planned} <-
           ChangePlanner.prepare(plan.action_id, input, state,
             id: plan.operation_id,
             timestamp: plan.wire_timestamp,
             today: plan.wire_today
           ),
         true <- planned.operation.operation_sha256 == operation.operation_sha256 do
      :ok
    else
      false -> protocol_error(:operation_changed)
      {:error, _error} = error -> error
    end
  end

  defp post_once(client, history_key, plan, operation) do
    case Client.commit(client, history_key, plan.ancestor_index, operation.body) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        decode_commit_ack(body, plan.ancestor_index)

      {:ok, %{status: status}} ->
        {:error,
         Error.provider("Things Cloud rejected the commit",
           provider: :things,
           reason: :commit_rejected,
           status: status,
           details: %{delivery: :rejected}
         )}

      {:error, reason} ->
        sent_outcome_unknown(reason)

      response ->
        sent_outcome_unknown(response)
    end
  rescue
    exception -> sent_outcome_unknown(exception)
  end

  defp decode_commit_ack(body, ancestor_index) do
    with {:ok, body} <- decode_object(body),
         head when is_integer(head) and head > ancestor_index <- body["server-head-index"] do
      {:ok, head}
    else
      _other -> sent_outcome_unknown(:invalid_commit_acknowledgement)
    end
  end

  defp verify(client, history_key, plan, operation, attempts, delay_ms) do
    expected_payload = operation.payload |> Jason.encode!() |> Jason.decode!()

    verified =
      case Client.history_page(client, history_key, plan.ancestor_index) do
        {:ok, %{"items" => items}} ->
          Enum.any?(items, fn
            item when is_map(item) ->
              case Map.get(item, operation.id) do
                %{"e" => "Task6", "t" => action, "p" => payload} ->
                  action == operation.action and payload == expected_payload

                _other ->
                  false
              end

            _item ->
              false
          end)

        _error ->
          false
      end

    cond do
      verified ->
        true

      attempts > 1 ->
        if delay_ms > 0, do: Process.sleep(delay_ms)
        verify(client, history_key, plan, operation, attempts - 1, delay_ms)

      true ->
        false
    end
  end

  defp validate_plan(plan, operation, connection) do
    cond do
      plan.connection_id != connection.id ->
        protocol_error(:prepared_connection_changed)

      plan.schema != Protocol.schema() ->
        protocol_error(:unsupported_schema)

      plan.operation_id != operation.id ->
        protocol_error(:operation_id_changed)

      plan.operation_hash != operation.operation_sha256 ->
        protocol_error(:operation_changed)

      plan.body_hash != operation.body_sha256 ->
        protocol_error(:prepared_body_changed)

      plan.confirmation != confirmation(%{plan | confirmation: ""}) ->
        protocol_error(:confirmation_changed)

      true ->
        :ok
    end
  end

  defp validate_account_binding(plan, client, account) do
    cond do
      plan.account_binding != Protocol.account_binding(client) ->
        protocol_error(:account_changed)

      plan.history_fingerprint != Protocol.history_fingerprint(account) ->
        protocol_error(:history_changed)

      true ->
        :ok
    end
  end

  defp validate_fresh_head(plan, history) do
    cond do
      history.schema != plan.schema ->
        protocol_error(:unsupported_schema)

      history.head != plan.ancestor_index ->
        protocol_error(:stale_provider_head, %{
          expected_head: plan.ancestor_index,
          observed_head: history.head
        })

      true ->
        :ok
    end
  end

  defp rebuild_operation(%Plan{action_id: "things.todo.create"} = plan, input) do
    normalized =
      input
      |> Map.put(:schedule, get_in(plan.preview, [:after, :schedule]))
      |> Map.put(:area_ids, get_in(plan.preview, [:after, :area_ids]))
      |> Map.put(:project_ids, get_in(plan.preview, [:after, :project_ids]))
      |> Map.put(:heading_ids, get_in(plan.preview, [:after, :heading_ids]))

    WriteWire.create_task(plan.operation_id, normalized, plan.wire_timestamp, plan.wire_today)
  end

  defp rebuild_operation(%Plan{} = plan, input) do
    WriteWire.update(
      plan.operation_id,
      operation_attrs(plan.action_id, input, plan),
      plan.wire_timestamp,
      plan.wire_today
    )
  end

  defp operation_attrs("things.todo.update", input, _plan), do: Map.take(input, [:title, :notes])
  defp operation_attrs("things.todo.schedule", input, _plan), do: %{schedule: input.schedule}
  defp operation_attrs("things.todo.deadline.set", input, _plan), do: %{deadline: input.deadline}
  defp operation_attrs("things.todo.deadline.clear", _input, _plan), do: %{deadline: nil}
  defp operation_attrs("things.todo.tags.set", input, _plan), do: %{tag_ids: input.tag_ids}

  defp operation_attrs("things.todo.move", input, plan) do
    %{
      area_ids: singleton(Map.get(input, :area_id)),
      project_ids: singleton(Map.get(input, :project_id)),
      heading_ids: singleton(Map.get(input, :heading_id))
    }
    |> maybe_put_schedule(
      get_in(plan.preview, [:after, :schedule]),
      get_in(plan.preview, [:before, :schedule])
    )
  end

  defp operation_attrs(action_id, _input, plan)
       when action_id in ["things.todo.complete", "things.todo.cancel"] do
    status = if action_id == "things.todo.complete", do: :completed, else: :canceled
    %{status: status, stopped_at: plan.wire_timestamp}
  end

  defp operation_attrs("things.todo.reopen", _input, _plan), do: %{status: :open, stopped_at: nil}
  defp operation_attrs("things.todo.trash", _input, _plan), do: %{in_trash: true}
  defp operation_attrs("things.todo.restore", _input, _plan), do: %{in_trash: false}

  defp maybe_put_schedule(attrs, value, value), do: attrs
  defp maybe_put_schedule(attrs, value, _before), do: Map.put(attrs, :schedule, value)
  defp singleton(nil), do: []
  defp singleton(value), do: [value]

  defp require_commit_option(opts) do
    if option(opts, :commit?) == true do
      :ok
    else
      {:error,
       Error.auth("Explicit Things commit option is required",
         reason: :commit_option_required
       )}
    end
  end

  defp require_risk_gate(%Plan{risk: :normal}, _opts), do: :ok

  defp require_risk_gate(%Plan{risk: :high}, opts) do
    if option(opts, :high_risk?) == true,
      do: :ok,
      else:
        {:error,
         Error.auth("Explicit Things high-risk confirmation is required",
           reason: :high_risk_confirmation_required
         )}
  end

  defp require_risk_gate(%Plan{risk: :destructive}, opts) do
    if option(opts, :high_risk?) == true and option(opts, :destructive?) == true,
      do: :ok,
      else:
        {:error,
         Error.auth("Explicit Things destructive confirmation is required",
           reason: :destructive_confirmation_required
         )}
  end

  defp confirmation(%Plan{} = plan) do
    plan
    |> Map.from_struct()
    |> Map.put(:confirmation, "")
    |> ExecutionSnapshot.hash()
    |> binary_part(0, 32)
  end

  defp sent_outcome_unknown(reason) do
    {:error,
     Error.provider("Things Cloud commit delivery is uncertain",
       provider: :things,
       reason: :sent_outcome_unknown,
       details: %{
         delivery: :sent_outcome_unknown,
         transport: Jido.Connect.Sanitizer.provider_body_summary(reason, :transport)
       }
     )}
  end

  defp decode_object(body) when is_map(body), do: {:ok, body}

  defp decode_object(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      _other -> :error
    end
  end

  defp decode_object(_body), do: :error

  defp protocol_error(reason, details \\ %{}), do: Protocol.error(reason, details)

  defp timestamp(opts) do
    case option(opts, :now) do
      %DateTime{} = datetime -> DateTime.to_unix(datetime, :microsecond) / 1_000_000
      function when is_function(function, 0) -> timestamp(now: function.())
      nil -> System.system_time(:microsecond) / 1_000_000
      value -> value
    end
  end

  defp today(opts) do
    case option(opts, :today) do
      %Date{} = date -> date
      nil -> Date.utc_today()
      _value -> Date.utc_today()
    end
  end

  defp id_generator(opts), do: option(opts, :id_generator) || (&Identifier.new/0)

  defp verification_attempts(opts) do
    case option(opts, :verification_attempts) do
      value when is_integer(value) and value in 1..10 -> value
      _value -> 1
    end
  end

  defp verification_delay(opts) do
    case option(opts, :verification_delay_ms) do
      value when is_integer(value) and value in 0..5_000 -> value
      _value -> 0
    end
  end

  defp local_account_lock(account_binding, function) do
    :global.trans({{__MODULE__, account_binding}, self()}, function)
  end

  defp option(opts, key) when is_list(opts), do: Keyword.get(opts, key)
  defp option(opts, key) when is_map(opts), do: Map.get(opts, key)
end
