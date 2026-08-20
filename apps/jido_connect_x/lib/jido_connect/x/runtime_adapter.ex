defmodule Jido.Connect.X.RuntimeAdapter do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.MCP.Runtime, as: MCPRuntime
  alias Jido.Connect.X.{Contract, Identity, Input, Normalizer, Router}

  @timeout 30_000

  def execute(action_id, raw_input, runtime) do
    with {:ok, identity} <- Identity.from_runtime(runtime),
         {:ok, input} <- Input.validate(action_id, raw_input),
         descriptor = Contract.fetch_action!(action_id),
         call = remote_caller(runtime),
         {:ok, identity_raw} <- call.("get_users_me", %{}),
         {:ok, account} <- Normalizer.account(identity_raw),
         :ok <- verify_account(identity, account),
         {:ok, result} <- result(action_id, descriptor, input, account, call) do
      {:ok, result}
    end
  rescue
    error in ArgumentError ->
      {:error,
       Error.validation("Unknown X action",
         reason: :unknown_x_action,
         subject: Exception.message(error)
       )}
  end

  defp result("x.account.get", _descriptor, _input, account, _call),
    do: {:ok, account}

  defp result(action, descriptor, input, account, call) do
    with {:ok, raw_result} <-
           call.(Router.tool(descriptor), Router.arguments(descriptor, input, account)) do
      Normalizer.list(action, input, account, raw_result)
    end
  end

  defp verify_account(%Identity{} = identity, %{username: authenticated}) do
    if Identity.matches_authenticated_username?(identity, authenticated) do
      :ok
    else
      {:error,
       Error.auth("Authenticated X account does not match the selected connection",
         reason: :x_account_mismatch,
         details: %{provider: :x}
       )}
    end
  end

  defp remote_caller(runtime) do
    timeout = Map.get(runtime, :request_timeout_ms) || @timeout

    fn tool, arguments ->
      input = %{
        endpoint_id: Contract.endpoint_id(),
        tool_name: tool,
        arguments: arguments,
        required_schema: Contract.tool_schema(tool),
        timeout: timeout
      }

      case MCPRuntime.call_typed_tool(input, runtime, mutation?: false) do
        {:ok, %{result: %{is_error?: false, raw: raw}}} -> {:ok, raw}
        {:ok, %{result: %{is_error?: true}}} -> remote_tool_error()
        {:error, error} -> {:error, translate_error(error)}
      end
    end
  end

  defp remote_tool_error do
    {:error,
     Error.provider("X MCP tool returned an error",
       provider: :x,
       reason: :remote_tool_error,
       delivery: :response_received,
       mutation?: false,
       provider_idempotency?: false,
       details: %{provider: :x}
     )}
  end

  defp translate_error(%Error.AuthError{} = error), do: error

  defp translate_error(%Error.ValidationError{} = error) do
    Error.provider("X MCP contract validation failed",
      provider: :x,
      reason: error.reason || :mcp_contract_validation_failed,
      delivery: :not_sent,
      mutation?: false,
      provider_idempotency?: false,
      details: %{provider: :x}
    )
  end

  defp translate_error(%Error.ProviderError{} = error) do
    Error.provider("X MCP request failed",
      provider: :x,
      reason: error.reason || :mcp_request_failed,
      status: error.status,
      delivery: error.delivery,
      mutation?: false,
      provider_idempotency?: false,
      details: %{provider: :x}
    )
  end

  defp translate_error(error) do
    Error.provider("X MCP request failed",
      provider: :x,
      reason: :mcp_request_failed,
      delivery: :unknown,
      mutation?: false,
      provider_idempotency?: false,
      details: %{error_type: error_type(error)}
    )
  end

  defp error_type(%{__struct__: module}), do: inspect(module)
  defp error_type(_error), do: "unknown"
end
