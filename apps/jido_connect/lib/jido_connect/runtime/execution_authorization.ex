defmodule Jido.Connect.ExecutionAuthorization do
  @moduledoc """
  Validates host-issued execution authorization for a prepared action.

  A boolean is never valid authorization evidence. The host must supply a
  validator callback that checks its evidence against the prepared action.
  """

  require Logger

  alias Jido.Connect.{ActionSpec, Callback, Context, Error, PreparedAction}

  @ai_actor_types [:agent, :ai, :assistant, "agent", "ai", "assistant"]

  @callback validate(term(), PreparedAction.t(), Context.t(), map()) :: term()

  @spec confirmation_required?(ActionSpec.t(), Context.t()) :: boolean()
  def confirmation_required?(%ActionSpec{} = action, %Context{} = context) do
    destructive?(action) or
      action.confirmation == :always or
      (action.confirmation == :required_for_ai and actor_type(context) in @ai_actor_types) or
      action.confirmation not in [:none, :required_for_ai, :always]
  end

  @spec require_direct_allowed(ActionSpec.t(), Context.t(), keyword() | map()) ::
          :ok | {:error, Error.error()}
  def require_direct_allowed(%ActionSpec{} = action, %Context{} = context, opts) do
    if confirmation_required?(action, context) do
      case option(opts, :direct_mutation_mode) ||
             Application.get_env(:jido_connect, :direct_mutation_mode, :allow) do
        :allow ->
          Logger.warning(
            "Direct mutation invocation is deprecated. Use Jido.Connect.prepare/4 and commit/4.",
            action_id: action.id
          )

          :ok

        :deny ->
          {:error, authorization_required(action.id)}

        mode ->
          {:error,
           Error.config("Invalid direct mutation mode",
             key: :direct_mutation_mode,
             details: %{mode: mode}
           )}
      end
    else
      :ok
    end
  end

  @spec validate(PreparedAction.t(), Context.t(), keyword() | map()) ::
          :ok | {:error, Error.error()}
  def validate(%PreparedAction{confirmation_required?: false}, %Context{}, _opts), do: :ok

  def validate(%PreparedAction{} = prepared, %Context{} = context, opts) do
    authorization = option(opts, :execution_authorization)
    validator = option(opts, :authorization_validator)
    validator_context = option(opts, :authorization_context) || %{}

    cond do
      is_nil(authorization) or is_boolean(authorization) ->
        {:error, authorization_required(prepared.action_id)}

      is_nil(validator) ->
        {:error,
         Error.auth("Execution authorization validator is required",
           reason: :authorization_validator_required,
           details: %{action_id: prepared.action_id, prepared_action_id: prepared.id}
         )}

      true ->
        validator
        |> call_validator(authorization, prepared, context, validator_context)
        |> normalize_result(prepared)
    end
  end

  defp call_validator(validator, authorization, prepared, context, validator_context)
       when is_function(validator, 4) do
    Callback.run(fn -> validator.(authorization, prepared, context, validator_context) end,
      phase: :authorization,
      details: %{action_id: prepared.action_id, prepared_action_id: prepared.id}
    )
  end

  defp call_validator(validator, authorization, prepared, context, _validator_context)
       when is_function(validator, 3) do
    Callback.run(fn -> validator.(authorization, prepared, context) end,
      phase: :authorization,
      details: %{action_id: prepared.action_id, prepared_action_id: prepared.id}
    )
  end

  defp call_validator(module, authorization, prepared, context, validator_context)
       when is_atom(module) do
    cond do
      function_exported?(module, :validate, 4) ->
        Callback.call(
          module,
          :validate,
          [authorization, prepared, context, validator_context],
          phase: :authorization,
          details: %{action_id: prepared.action_id, prepared_action_id: prepared.id}
        )

      function_exported?(module, :validate, 3) ->
        Callback.call(module, :validate, [authorization, prepared, context],
          phase: :authorization,
          details: %{action_id: prepared.action_id, prepared_action_id: prepared.id}
        )

      true ->
        {:error,
         Error.config("Authorization validator does not export validate/3 or validate/4",
           key: :authorization_validator,
           details: %{module: module}
         )}
    end
  end

  defp call_validator({module, function}, authorization, prepared, context, validator_context)
       when is_atom(module) and is_atom(function) do
    Callback.call(module, function, [authorization, prepared, context, validator_context],
      phase: :authorization,
      details: %{action_id: prepared.action_id, prepared_action_id: prepared.id}
    )
  end

  defp call_validator(_validator, _authorization, prepared, _context, _validator_context) do
    {:error,
     Error.config("Invalid execution authorization validator",
       key: :authorization_validator,
       details: %{action_id: prepared.action_id}
     )}
  end

  defp normalize_result({:ok, result}, _prepared)
       when result in [:ok, true, :allow, :allowed] do
    :ok
  end

  defp normalize_result({:ok, {:ok, _value}}, _prepared), do: :ok
  defp normalize_result({:error, %_{} = error}, _prepared), do: {:error, error}

  defp normalize_result(_result, prepared) do
    {:error,
     Error.auth("Execution authorization is invalid",
       reason: :invalid_execution_authorization,
       details: %{action_id: prepared.action_id, prepared_action_id: prepared.id}
     )}
  end

  defp authorization_required(action_id) do
    Error.auth("Prepared execution authorization is required",
      reason: :execution_authorization_required,
      details: %{action_id: action_id}
    )
  end

  defp destructive?(%ActionSpec{risk: risk}), do: risk in [:destructive, :dangerous]

  defp actor_type(%Context{actor: actor}) when is_map(actor) do
    Map.get(actor, :type) || Map.get(actor, "type")
  end

  defp actor_type(_context), do: nil

  defp option(opts, key) when is_list(opts), do: Keyword.get(opts, key)
  defp option(opts, key) when is_map(opts), do: Map.get(opts, key)
end
