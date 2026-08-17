defmodule Jido.Connect.Things.Writer do
  @moduledoc """
  Guarded prepare and single-send commit runtime for Things Cloud writes.

  Prepare performs provider reads only. Commit rechecks the exact account,
  schema, provider head, input, plan, and update target before it sends one
  request. The writer does not retry a commit.
  """

  alias Jido.Connect.{Connection, Error, ExecutionSnapshot}

  alias Jido.Connect.Things.{
    Client,
    Identifier,
    Input,
    Protocol,
    ReadAdapter,
    Reader,
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
      :expected_modified_at,
      :risk,
      :preview,
      :confirmation
    ]
    defstruct @enforce_keys

    def to_public_map(%__MODULE__{} = plan), do: Map.from_struct(plan)
  end

  @write_actions ["things.todo.create", "things.todo.update"]

  def prepare(action_id, input, client, connection, opts \\ [])

  def prepare(action_id, input, %Client{} = client, %Connection{} = connection, opts)
      when action_id in @write_actions do
    with {:ok, input} <- Input.parse(action_id, input),
         :ok <- Protocol.validate_endpoint(client),
         {:ok, account, history} <- Reader.snapshot(client),
         {:ok, operation, preview, expected_modified_at, wire_timestamp} <-
           prepare_operation(action_id, input, client, connection, account, history, opts) do
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
        expected_modified_at: expected_modified_at,
        risk: :external_write,
        preview: preview,
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
         {:ok, operation} <- rebuild_operation(plan, input),
         :ok <- validate_plan(plan, operation, connection) do
      lock = option(opts, :lock) || (&local_account_lock/2)

      case lock.(plan.account_binding, fn ->
             preflight_and_commit(plan, input, operation, client, connection)
           end) do
        :aborted ->
          protocol_error(:write_lock_unavailable)

        result ->
          result
      end
    end
  end

  defp prepare_operation(
         "things.todo.create",
         input,
         _client,
         _connection,
         _account,
         _history,
         opts
       ) do
    id = id_generator(opts).()
    wire_timestamp = timestamp(opts)

    with {:ok, operation} <-
           WriteWire.create(id, input.title, Map.get(input, :notes), wire_timestamp) do
      {:ok, operation,
       %{
         operation: "create",
         destination: "inbox",
         title: input.title,
         notes_present: Map.has_key?(input, :notes),
         planned_external_id: id
       }, nil, wire_timestamp}
    end
  end

  defp prepare_operation(
         "things.todo.update",
         input,
         client,
         connection,
         account,
         history,
         opts
       ) do
    wire_timestamp = timestamp(opts)

    with {:ok, todo} <- prepare_todo(input.id, client, connection, account, history, opts),
         :ok <- validate_eligible(todo),
         :ok <- validate_expected_modified_at(todo, input.expected_modified_at),
         {:ok, operation} <- WriteWire.update(input.id, input, wire_timestamp) do
      changed_fields =
        [:title, :notes]
        |> Enum.filter(&Map.has_key?(input, &1))
        |> Enum.map(&Atom.to_string/1)

      {:ok, operation,
       %{
         operation: "update",
         task_id: input.id,
         changed_fields: changed_fields,
         expected_modified_at: input.expected_modified_at
       }, input.expected_modified_at, wire_timestamp}
    end
  end

  defp prepare_todo(id, client, connection, account, history, opts) do
    case option(opts, :read_adapter) do
      nil ->
        find_provider_todo(client, account, history, id)

      adapter ->
        with {:ok, result} <- ReadAdapter.get(adapter, connection.id, id, history.head),
             :ok <- validate_adapter_head(result, history.head),
             {:ok, todo} <- normalize_adapter_todo(result) do
          {:ok, todo}
        end
    end
  end

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

  defp preflight_and_commit(plan, input, operation, client, connection) do
    with :ok <- Protocol.validate_endpoint(client),
         {:ok, account} <- Client.verify_account(client),
         :ok <- Protocol.validate_account(client, account),
         :ok <- validate_account_binding(plan, client, account),
         {:ok, history} <- Client.history(client, account.history_key),
         :ok <- Protocol.validate_history(history),
         :ok <- validate_fresh_head(plan, history),
         :ok <- recheck_update(plan.action_id, input, client, account, history),
         {:ok, server_head} <- post_once(client, account.history_key, plan, operation),
         verified <- verify(client, account.history_key, plan, operation) do
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

  defp recheck_update("things.todo.create", _input, _client, _account, _history), do: :ok

  defp recheck_update("things.todo.update", input, client, account, history) do
    with {:ok, todo} <- find_provider_todo(client, account, history, input.id),
         :ok <- validate_eligible(todo),
         :ok <- validate_expected_modified_at(todo, input.expected_modified_at) do
      :ok
    end
  end

  defp find_provider_todo(client, account, history, id) do
    with {:ok, todos} <- Reader.load(client, account, history) do
      case Enum.find(todos, &(&1.id == id)) do
        %Todo{} = todo -> {:ok, todo}
        nil -> protocol_error(:todo_not_found, %{id: id})
      end
    end
  end

  defp validate_eligible(%Todo{} = todo) do
    if Todo.eligible_inbox?(todo) do
      :ok
    else
      protocol_error(:todo_not_open_inbox, %{id: todo.id})
    end
  end

  defp validate_expected_modified_at(%Todo{} = todo, expected) do
    actual = DateTime.to_iso8601(todo.modified_at)

    case DateTime.from_iso8601(expected) do
      {:ok, expected_datetime, 0} ->
        if DateTime.compare(todo.modified_at, expected_datetime) == :eq do
          :ok
        else
          protocol_error(:stale_expected_modified_at, %{id: todo.id, actual_modified_at: actual})
        end

      _error ->
        protocol_error(:stale_expected_modified_at, %{id: todo.id, actual_modified_at: actual})
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

  defp verify(client, history_key, plan, operation) do
    expected_payload = operation.payload |> Jason.encode!() |> Jason.decode!()

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
    WriteWire.create(plan.operation_id, input.title, Map.get(input, :notes), plan.wire_timestamp)
  end

  defp rebuild_operation(%Plan{action_id: "things.todo.update"} = plan, input) do
    WriteWire.update(plan.operation_id, input, plan.wire_timestamp)
  end

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

  defp id_generator(opts), do: option(opts, :id_generator) || (&Identifier.new/0)

  defp local_account_lock(account_binding, function) do
    :global.trans({{__MODULE__, account_binding}, self()}, function)
  end

  defp option(opts, key) when is_list(opts), do: Keyword.get(opts, key)
  defp option(opts, key) when is_map(opts), do: Map.get(opts, key)
end
