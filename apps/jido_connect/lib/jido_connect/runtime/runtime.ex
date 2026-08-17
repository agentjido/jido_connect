defmodule Jido.Connect.Runtime do
  @moduledoc false

  alias Jido.Connect.{
    ActionSpec,
    Authorization,
    Callback,
    Context,
    CredentialLease,
    Error,
    ExecutionAuthorization,
    ExecutionSnapshot,
    PreparedAction,
    Spec,
    Telemetry,
    TriggerSpec
  }

  @doc false
  def invoke(%Spec{} = integration, action_id, input, opts) do
    Telemetry.span(:invoke, telemetry_metadata(integration, action_id, opts), fn ->
      do_invoke(integration, action_id, input, opts)
    end)
  end

  @doc false
  def prepare(%Spec{} = integration, action_id, input, opts) do
    Telemetry.span(:prepare, telemetry_metadata(integration, action_id, opts), fn ->
      do_prepare(integration, action_id, input, opts)
    end)
  end

  @doc false
  def commit(%Spec{} = integration, %PreparedAction{} = prepared, input, opts) do
    Telemetry.span(:commit, telemetry_metadata(integration, prepared.action_id, opts), fn ->
      do_commit(integration, prepared, input, opts)
    end)
  end

  @doc false
  def poll(%Spec{} = integration, trigger_id, config, opts) do
    Telemetry.span(:poll, telemetry_metadata(integration, trigger_id, opts), fn ->
      do_poll(integration, trigger_id, config, opts)
    end)
  end

  defp do_invoke(%Spec{} = integration, action_id, input, opts) do
    with {:ok, action} <- find_action(integration, action_id),
         {:ok, parsed_input} <- parse_schema(action.input_schema, input, :input),
         {:ok, context} <- fetch_context(opts),
         {:ok, lease} <- fetch_credential_lease(opts),
         :ok <- ExecutionAuthorization.require_direct_allowed(action, context, opts),
         :ok <- Authorization.authorize(action, parsed_input, context, lease, auth_opts(opts)),
         {:ok, output} <-
           run_action_handler(action, parsed_input, %{
             integration: integration,
             action: action,
             context: context,
             credential_lease: lease,
             credentials: lease.fields,
             provider_client: get_option(opts, :provider_client)
           }),
         {:ok, parsed_output} <- parse_schema(action.output_schema, output, :output) do
      {:ok, parsed_output}
    end
  end

  defp do_prepare(%Spec{} = integration, action_id, input, opts) do
    with {:ok, action} <- find_action(integration, action_id),
         {:ok, parsed_input} <- parse_schema(action.input_schema, input, :input),
         {:ok, context} <- fetch_context(opts),
         {:ok, lease} <- fetch_credential_lease(opts),
         :ok <- Authorization.authorize(action, parsed_input, context, lease, auth_opts(opts)),
         {:ok, ttl_ms} <- prepare_ttl_ms(opts) do
      now = get_option(opts, :now) || DateTime.utc_now()
      expires_at = earliest_expiry(DateTime.add(now, ttl_ms, :millisecond), lease.expires_at)
      connection = context.connection

      {:ok,
       %PreparedAction{
         id: prepared_id(),
         integration_id: integration.id,
         action_id: action.id,
         connection_id: connection.id,
         input_hash: ExecutionSnapshot.hash(parsed_input),
         action_hash: ExecutionSnapshot.action_hash(action),
         connection_hash: ExecutionSnapshot.connection_hash(connection),
         lease_hash: ExecutionSnapshot.lease_hash(lease),
         binding_hash: ExecutionSnapshot.hash(get_option(opts, :binding_ref)),
         risk: action.risk,
         confirmation: action.confirmation,
         confirmation_required?: ExecutionAuthorization.confirmation_required?(action, context),
         preview: ExecutionSnapshot.preview(action, parsed_input, connection),
         execution_id: get_option(opts, :execution_id),
         idempotency_key: get_option(opts, :idempotency_key),
         prepared_at: now,
         expires_at: expires_at
       }}
    end
  end

  defp do_commit(%Spec{} = integration, %PreparedAction{} = prepared, input, opts) do
    with :ok <- require_unexpired_prepared(prepared, opts),
         {:ok, action} <- find_action(integration, prepared.action_id),
         {:ok, parsed_input} <- parse_schema(action.input_schema, input, :input),
         {:ok, context} <- fetch_context(opts),
         {:ok, lease} <- fetch_credential_lease(opts),
         :ok <- Authorization.authorize(action, parsed_input, context, lease, auth_opts(opts)),
         :ok <-
           require_matching_snapshot(
             integration,
             action,
             parsed_input,
             context,
             lease,
             prepared,
             opts
           ),
         :ok <- ExecutionAuthorization.validate(prepared, context, opts),
         {:ok, output} <-
           run_action_handler(action, parsed_input, %{
             integration: integration,
             action: action,
             context: context,
             credential_lease: lease,
             credentials: lease.fields,
             provider_client: get_option(opts, :provider_client),
             execution: %{
               id: prepared.execution_id,
               prepared_action_id: prepared.id,
               idempotency_key: prepared.idempotency_key
             }
           }),
         {:ok, parsed_output} <- parse_schema(action.output_schema, output, :output) do
      {:ok, parsed_output}
    end
  end

  defp do_poll(%Spec{} = integration, trigger_id, config, opts) do
    with {:ok, trigger} <- find_trigger(integration, trigger_id),
         {:ok, parsed_config} <- parse_schema(trigger.config_schema, config, :config),
         {:ok, context} <- fetch_context(opts),
         {:ok, lease} <- fetch_credential_lease(opts),
         :ok <- Authorization.authorize(trigger, parsed_config, context, lease, auth_opts(opts)),
         {:ok, result} <-
           run_poll_handler(trigger, parsed_config, %{
             integration: integration,
             trigger: trigger,
             context: context,
             credential_lease: lease,
             credentials: lease.fields,
             checkpoint: get_option(opts, :checkpoint)
           }),
         {:ok, signals} <- validate_signals(trigger, Map.get(result, :signals, [])) do
      {:ok, %{signals: signals, checkpoint: Map.get(result, :checkpoint)}}
    end
  end

  defp find_action(%Spec{} = integration, action_id) do
    case Enum.find(integration.actions, &(&1.id == action_id)) do
      %ActionSpec{} = action -> {:ok, action}
      nil -> {:error, Error.unknown_action(action_id)}
    end
  end

  defp find_trigger(%Spec{} = integration, trigger_id) do
    case Enum.find(integration.triggers, &(&1.id == trigger_id)) do
      %TriggerSpec{} = trigger -> {:ok, trigger}
      nil -> {:error, Error.unknown_trigger(trigger_id)}
    end
  end

  defp fetch_context(opts) do
    case fetch_option(opts, :context) do
      {:ok, %Context{} = context} ->
        {:ok, context}

      {:ok, attrs} when is_map(attrs) ->
        attrs |> Context.new() |> normalize_schema_result(:context)

      :error ->
        {:error, Error.context_required()}
    end
  end

  defp fetch_credential_lease(opts) do
    case fetch_option(opts, :credential_lease) do
      {:ok, %CredentialLease{} = lease} ->
        {:ok, lease}

      {:ok, attrs} when is_map(attrs) ->
        attrs |> CredentialLease.new() |> normalize_schema_result(:credential_lease)

      :error ->
        {:error, Error.credential_lease_required()}
    end
  end

  defp run_action_handler(%ActionSpec{} = action, input, context) do
    with {:ok, result} <-
           Callback.call(action.handler, :run, [input, context],
             phase: :handler,
             details: %{operation_id: action.id}
           ) do
      normalize_handler_result(result, :handler, action.id)
    end
  end

  defp run_poll_handler(%TriggerSpec{} = trigger, config, context) do
    with {:ok, result} <-
           Callback.call(trigger.handler, :poll, [config, context],
             phase: :handler,
             details: %{operation_id: trigger.id}
           ) do
      normalize_handler_result(result, :handler, trigger.id)
    end
  end

  defp normalize_handler_result({:ok, value}, _phase, _operation_id), do: {:ok, value}

  defp normalize_handler_result({:error, %_module{} = error}, phase, operation_id) do
    if Error.error?(error) do
      {:error, error}
    else
      normalize_handler_result({:error, Map.from_struct(error)}, phase, operation_id)
    end
  end

  defp normalize_handler_result({:error, reason}, phase, operation_id) do
    {:error,
     Error.execution("Provider handler failed",
       phase: phase,
       details: %{
         operation_id: operation_id,
         error: Jido.Connect.Sanitizer.sanitize(reason, :transport)
       }
     )}
  end

  defp normalize_handler_result(result, phase, operation_id) do
    {:error,
     Error.execution("Provider handler returned an invalid result",
       phase: phase,
       details: %{
         operation_id: operation_id,
         returned: Jido.Connect.Sanitizer.sanitize(result, :transport)
       }
     )}
  end

  defp validate_signals(%TriggerSpec{} = trigger, signals) when is_list(signals) do
    Enum.reduce_while(signals, {:ok, []}, fn signal, {:ok, acc} ->
      case Zoi.parse(trigger.signal_schema, signal) do
        {:ok, parsed} -> {:cont, {:ok, acc ++ [parsed]}}
        {:error, error} -> {:halt, {:error, Error.zoi(:signal, error, %{trigger_id: trigger.id})}}
      end
    end)
  end

  defp validate_signals(%TriggerSpec{} = trigger, signals) do
    {:error,
     Error.execution("Provider poll handler returned invalid signals",
       phase: :handler,
       details: %{
         operation_id: trigger.id,
         expected: :list,
         returned: Jido.Connect.Sanitizer.sanitize(signals, :transport)
       }
     )}
  end

  defp parse_schema(schema, value, reason) do
    case Zoi.parse(schema, value) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, errors} -> {:error, Error.zoi(reason, errors)}
    end
  end

  defp normalize_schema_result({:ok, parsed}, _reason), do: {:ok, parsed}
  defp normalize_schema_result({:error, errors}, reason), do: {:error, Error.zoi(reason, errors)}

  defp prepare_ttl_ms(opts) do
    value = get_option(opts, :prepare_ttl_ms) || 300_000

    if is_integer(value) and value > 0 do
      {:ok, value}
    else
      {:error,
       Error.validation("Prepare TTL must be a positive integer",
         reason: :invalid_prepare_ttl,
         subject: value
       )}
    end
  end

  defp earliest_expiry(left, right) do
    case DateTime.compare(left, right) do
      :gt -> right
      _other -> left
    end
  end

  defp prepared_id do
    24
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  defp require_unexpired_prepared(prepared, opts) do
    now = get_option(opts, :now) || DateTime.utc_now()

    if PreparedAction.expired?(prepared, now) do
      {:error,
       Error.auth("Prepared action has expired",
         reason: :prepared_action_expired,
         details: %{prepared_action_id: prepared.id, expires_at: prepared.expires_at}
       )}
    else
      :ok
    end
  end

  defp require_matching_snapshot(integration, action, input, context, lease, prepared, opts) do
    current = %{
      integration_id: integration.id,
      action_id: action.id,
      connection_id: context.connection.id,
      input_hash: ExecutionSnapshot.hash(input),
      action_hash: ExecutionSnapshot.action_hash(action),
      connection_hash: ExecutionSnapshot.connection_hash(context.connection),
      lease_hash: ExecutionSnapshot.lease_hash(lease),
      binding_hash: ExecutionSnapshot.hash(get_option(opts, :binding_ref)),
      execution_id: get_option(opts, :execution_id),
      idempotency_key: get_option(opts, :idempotency_key)
    }

    changed =
      Enum.find(Map.keys(current), fn field ->
        Map.fetch!(current, field) != Map.fetch!(prepared, field)
      end)

    if changed do
      {:error,
       Error.auth("Prepared action state changed before commit",
         reason: :prepared_action_stale,
         connection_id: context.connection.id,
         details: %{prepared_action_id: prepared.id, changed: changed}
       )}
    else
      :ok
    end
  end

  defp fetch_option(opts, key) when is_list(opts), do: Keyword.fetch(opts, key)
  defp fetch_option(opts, key) when is_map(opts), do: Map.fetch(opts, key)

  defp get_option(opts, key) when is_list(opts), do: Keyword.get(opts, key)
  defp get_option(opts, key) when is_map(opts), do: Map.get(opts, key)

  defp auth_opts(opts) do
    %{
      policy: get_option(opts, :policy),
      policy_context: get_option(opts, :policy_context)
    }
  end

  defp telemetry_metadata(%Spec{} = integration, operation_id, opts) do
    context = get_option(opts, :context)
    lease = get_option(opts, :credential_lease)
    connection = context_connection(context)

    %{
      integration_id: integration.id,
      operation_id: operation_id,
      tenant_id: context_field(context, :tenant_id),
      actor_type: actor_type(context),
      connection_id: connection_field(connection, :id),
      auth_profile: connection_field(connection, :profile),
      credential_lease_connection_id: credential_lease_connection_id(lease)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp context_connection(%Context{connection: connection}), do: connection
  defp context_connection(%{connection: connection}), do: connection
  defp context_connection(_context), do: nil

  defp context_field(%Context{} = context, field), do: Map.get(context, field)
  defp context_field(context, field) when is_map(context), do: Map.get(context, field)
  defp context_field(_context, _field), do: nil

  defp actor_type(%Context{actor: actor}), do: actor_type(actor)
  defp actor_type(%{actor: actor}), do: actor_type(actor)
  defp actor_type(%{type: type}), do: type
  defp actor_type(%{"type" => type}), do: type
  defp actor_type(_context), do: nil

  defp connection_field(%Jido.Connect.Connection{} = connection, field),
    do: Map.get(connection, field)

  defp connection_field(connection, field) when is_map(connection), do: Map.get(connection, field)
  defp connection_field(_connection, _field), do: nil

  defp credential_lease_connection_id(%CredentialLease{connection_id: connection_id}),
    do: connection_id

  defp credential_lease_connection_id(%{connection_id: connection_id}), do: connection_id
  defp credential_lease_connection_id(_lease), do: nil
end
