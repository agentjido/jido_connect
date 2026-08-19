defmodule Jido.Connect.Trello.RuntimeAdapter do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.MCP.Runtime, as: MCPRuntime
  alias Jido.Connect.Trello.{BoardIdentity, Contract, Input, Normalizer, Router, Scope}

  @timeout 30_000

  def execute(action_id, raw_input, runtime) do
    with {:ok, identity} <- BoardIdentity.from_runtime(runtime),
         {:ok, input} <- Input.validate(action_id, raw_input),
         descriptor = Contract.fetch_action!(action_id),
         call = remote_caller(runtime),
         {:ok, board_raw} <-
           call.(
             "trelloReadBoard",
             %{action: "get", boardId: identity.board_url},
             false
           ),
         {:ok, board_result} <- Normalizer.normalize("trello.board.get", %{}, board_raw),
         :ok <- Scope.verify_board(identity, board_result),
         :ok <- Scope.verify_request(action_id, input, identity, call),
         {:ok, raw_result} <- result_call(action_id, descriptor, input, identity, board_raw, call),
         {:ok, result} <- Normalizer.normalize(action_id, input, raw_result),
         :ok <- Scope.verify_result(action_id, result, identity) do
      {:ok, result}
    end
  rescue
    error in ArgumentError ->
      {:error,
       Error.validation("Unknown Trello action",
         reason: :unknown_trello_action,
         subject: Exception.message(error)
       )}
  end

  defp result_call("trello.board.get", _descriptor, _input, _identity, board_raw, _call),
    do: {:ok, board_raw}

  defp result_call(action_id, descriptor, input, identity, _board_raw, call) do
    call.(
      Router.tool(descriptor, input),
      Router.arguments(descriptor, input, identity),
      Contract.mutation?(action_id)
    )
  end

  defp remote_caller(runtime) do
    fn tool, arguments, mutation? ->
      input = %{
        endpoint_id: Contract.endpoint_id(),
        tool_name: tool,
        arguments: arguments,
        expected_schema_hash: Contract.schema_hash(tool),
        timeout: @timeout
      }

      case MCPRuntime.call_typed_tool(input, runtime, mutation?: mutation?) do
        {:ok, %{result: %{is_error?: false, raw: raw}}} -> {:ok, raw}
        {:ok, %{result: %{is_error?: true}}} -> remote_tool_error(mutation?)
        {:error, error} -> {:error, translate_error(error, mutation?)}
      end
    end
  end

  defp remote_tool_error(mutation?) do
    {:error,
     Error.provider("Trello MCP tool returned an error",
       provider: :trello,
       reason: :remote_tool_error,
       delivery: :response_received,
       mutation?: mutation?,
       provider_idempotency?: false
     )}
  end

  defp translate_error(%Error.AuthError{} = error, _mutation?), do: error

  defp translate_error(%Error.ValidationError{} = error, mutation?) do
    Error.provider("Trello MCP contract validation failed",
      provider: :trello,
      reason: error.reason || :mcp_contract_validation_failed,
      delivery: :not_sent,
      mutation?: mutation?,
      provider_idempotency?: false,
      details: %{provider: :trello}
    )
  end

  defp translate_error(%Error.ProviderError{} = error, mutation?) do
    delivery =
      if mutation? and error.delivery not in [:rejected, :response_received],
        do: :sent_outcome_unknown,
        else: error.delivery

    Error.provider("Trello MCP request failed",
      provider: :trello,
      reason: error.reason || :mcp_request_failed,
      status: error.status,
      delivery: delivery,
      mutation?: mutation?,
      provider_idempotency?: false,
      details: %{provider: :trello}
    )
  end

  defp translate_error(error, mutation?) do
    Error.provider("Trello MCP request failed",
      provider: :trello,
      reason: :mcp_request_failed,
      delivery: if(mutation?, do: :sent_outcome_unknown, else: :unknown),
      mutation?: mutation?,
      provider_idempotency?: false,
      details: %{error_type: error_type(error)}
    )
  end

  defp error_type(%{__struct__: module}), do: inspect(module)
  defp error_type(_error), do: "unknown"
end
