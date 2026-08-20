defmodule Jido.Connect.Policy do
  @moduledoc """
  Storage-free host policy boundary for shared connection use.

  Core validates connection state, lease binding, auth profiles, and scopes.
  Host applications still decide whether a specific actor may use a user,
  tenant, installation, or system connection. Policies can be passed to
  `Jido.Connect.invoke/4`, `Jido.Connect.poll/4`, and generated plugin
  availability as a function, module, or `{module, function}` tuple.
  """

  alias Jido.Connect.{Callback, Connection, Context, Error}

  @type operation :: map()
  @type policy ::
          nil
          | module()
          | (operation(), map(), Context.t(), Connection.t() -> term())
          | (operation(), map(), Context.t(), Connection.t(), map() -> term())
          | {module(), atom()}
          | {module(), atom(), [term()]}

  @callback authorize(operation(), map(), Context.t(), Connection.t()) :: term()
  @callback authorize(operation(), map(), Context.t(), Connection.t(), map()) :: term()

  @doc "Applies a host-owned policy callback to a resolved connection."
  @spec authorize(policy(), operation(), map(), Context.t() | nil, Connection.t(), map()) ::
          :ok | {:error, Error.error()}
  def authorize(nil, operation, _input, _context, %Connection{} = connection, _policy_context) do
    if Map.get(operation, :host_policy_required?, false) do
      deny(:policy_required, operation, connection)
    else
      :ok
    end
  end

  def authorize(_policy, _operation, _input, nil, %Connection{}, _policy_context),
    do: {:error, Error.context_required()}

  def authorize(policy, operation, input, %Context{} = context, %Connection{} = connection, attrs)
      when is_map(input) and is_map(attrs) do
    policy
    |> call_policy(operation, input, context, connection, attrs)
    |> normalize_result(operation, connection)
  end

  defp call_policy(policy, operation, input, context, connection, _attrs)
       when is_function(policy, 4) do
    Callback.run(fn -> policy.(operation, input, context, connection) end,
      phase: :policy,
      details: %{operation_id: operation_id(operation), connection_id: connection.id}
    )
  end

  defp call_policy(policy, operation, input, context, connection, attrs)
       when is_function(policy, 5) do
    Callback.run(fn -> policy.(operation, input, context, connection, attrs) end,
      phase: :policy,
      details: %{operation_id: operation_id(operation), connection_id: connection.id}
    )
  end

  defp call_policy(module, operation, input, context, connection, attrs) when is_atom(module) do
    with {:module, ^module} <- Code.ensure_loaded(module) do
      cond do
        function_exported?(module, :authorize, 5) ->
          Callback.call(module, :authorize, [operation, input, context, connection, attrs],
            phase: :policy,
            details: %{operation_id: operation_id(operation), connection_id: connection.id}
          )

        function_exported?(module, :authorize, 4) ->
          Callback.call(module, :authorize, [operation, input, context, connection],
            phase: :policy,
            details: %{operation_id: operation_id(operation), connection_id: connection.id}
          )

        true ->
          {:error,
           Error.config("Policy module does not export authorize/4 or authorize/5",
             key: :policy,
             details: %{module: module}
           )}
      end
    else
      {:error, reason} ->
        {:error,
         Error.config("Policy module could not be loaded",
           key: :policy,
           details: %{module: module, reason: reason}
         )}
    end
  end

  defp call_policy({module, function}, operation, input, context, connection, _attrs)
       when is_atom(module) and is_atom(function) do
    Callback.call(module, function, [operation, input, context, connection],
      phase: :policy,
      details: %{operation_id: operation_id(operation), connection_id: connection.id}
    )
  end

  defp call_policy({module, function, extra_args}, operation, input, context, connection, _attrs)
       when is_atom(module) and is_atom(function) and is_list(extra_args) do
    Callback.call(module, function, [operation, input, context, connection | extra_args],
      phase: :policy,
      details: %{operation_id: operation_id(operation), connection_id: connection.id}
    )
  end

  defp call_policy(policy, _operation, _input, _context, _connection, _attrs) do
    {:error,
     Error.config("Policy must be a function, module, or module/function tuple",
       key: :policy,
       details: %{policy: inspect(policy)}
     )}
  end

  defp normalize_result({:error, %_{} = error}, operation, connection) do
    if Error.error?(error), do: {:error, error}, else: deny(error, operation, connection)
  end

  defp normalize_result({:ok, result}, operation, connection),
    do: normalize_policy_return(result, operation, connection)

  defp normalize_result(other, operation, connection),
    do: normalize_policy_return(other, operation, connection)

  defp normalize_policy_return(result, _operation, _connection)
       when result in [:ok, true, :allow, :allowed],
       do: :ok

  defp normalize_policy_return({:ok, _value}, _operation, _connection), do: :ok

  defp normalize_policy_return(result, operation, connection)
       when result in [:deny, :denied, false],
       do: deny(result, operation, connection)

  defp normalize_policy_return({:deny, reason}, operation, connection),
    do: deny(reason, operation, connection)

  defp normalize_policy_return({:error, %_{} = error}, operation, connection) do
    if Error.error?(error), do: {:error, error}, else: deny(error, operation, connection)
  end

  defp normalize_policy_return({:error, reason}, operation, connection),
    do: deny(reason, operation, connection)

  defp normalize_policy_return(result, operation, connection) do
    {:error,
     Error.config("Policy returned an invalid value",
       key: :policy,
       details: %{
         operation_id: operation_id(operation),
         connection_id: connection.id,
         returned: Jido.Connect.Sanitizer.sanitize(result, :transport)
       }
     )}
  end

  defp deny(reason, operation, %Connection{} = connection) do
    {:error,
     Error.policy_denied(connection.id,
       operation_id: operation_id(operation),
       reason: Jido.Connect.Sanitizer.sanitize(reason, :transport)
     )}
  end

  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(%{trigger_id: trigger_id}), do: trigger_id
  defp operation_id(%{id: id}), do: id
  defp operation_id(_operation), do: nil
end
