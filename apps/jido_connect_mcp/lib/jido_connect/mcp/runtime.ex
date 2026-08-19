defmodule Jido.Connect.MCP.Runtime do
  @moduledoc false

  alias Jido.Connect.Error
  alias Jido.Connect.MCP.{EndpointLeaseManager, EndpointResolver, Tool, ToolResult}

  def list_tools(input, opts) do
    with {:ok, token} <- EndpointResolver.resolve_lease(input.endpoint_id, opts) do
      try do
        with :ok <- ensure_dispatchable(token),
             {:ok, data} <-
               dispatch(token, fn ->
                 call_mcp(opts, :list_tools, [token.endpoint_id], timeout(input))
               end) do
          tools =
            data
            |> Map.get("tools", [])
            |> Enum.map(&Tool.from_mcp/1)
            |> Enum.map(&Tool.to_map/1)

          {:ok, %{endpoint_id: input.endpoint_id, tools: tools}}
        end
      after
        release(token)
      end
    end
  end

  def call_tool(input, opts) do
    call_typed_tool(input, opts, mutation?: true)
  end

  @doc false
  @spec call_typed_tool(map(), keyword() | map(), mutation?: boolean()) ::
          {:ok, map()} | {:error, Error.error()}
  def call_typed_tool(input, opts, execution_opts) do
    mutation? = Keyword.fetch!(execution_opts, :mutation?)

    with {:ok, token} <- EndpointResolver.resolve_lease(input.endpoint_id, opts) do
      try do
        with :ok <- ensure_dispatchable(token),
             :ok <- verify_schema(input, opts, token.endpoint_id),
             {:ok, data} <- call_typed(token, opts, input, mutation?) do
          result =
            input.endpoint_id
            |> ToolResult.from_mcp(input.tool_name, data)
            |> ToolResult.to_map()

          {:ok, %{result: result}}
        end
      after
        release(token)
      end
    end
  end

  defp call_typed(token, opts, input, true), do: call_write(token, opts, input)

  defp call_typed(token, opts, input, false) do
    dispatch(token, fn ->
      call_mcp(
        opts,
        :call_tool,
        [token.endpoint_id, input.tool_name, input.arguments],
        timeout(input)
      )
    end)
  end

  defp call_write(%{legacy?: true} = token, opts, input) do
    call_mcp(
      opts,
      :call_tool,
      [token.endpoint_id, input.tool_name, input.arguments],
      timeout(input)
    )
  end

  defp call_write(token, opts, input) do
    case EndpointLeaseManager.dispatch(token, fn ->
           call_mcp(
             opts,
             :call_tool,
             [token.endpoint_id, input.tool_name, input.arguments],
             timeout(input)
           )
         end) do
      {:ok, {:error, _error}, true} ->
        {:error,
         Error.provider("MCP write outcome is uncertain",
           provider: :mcp,
           reason: :mcp_write_uncertain,
           delivery: :sent_outcome_unknown,
           mutation?: true,
           details: %{endpoint_generation: token.generation}
         )}

      {:ok, result, _revoked?} ->
        result

      {:error, error} ->
        {:error, error}
    end
  end

  defp verify_schema(%{expected_schema_hash: nil}, _opts, _endpoint_id), do: :ok

  defp verify_schema(%{expected_schema_hash: expected_hash} = input, opts, endpoint_id) do
    with {:ok, data} <- call_mcp(opts, :list_tools, [endpoint_id], timeout(input)),
         {:ok, tool} <- find_tool(data, input.tool_name),
         actual_hash = tool |> Tool.from_mcp() |> Map.fetch!(:schema_hash),
         :ok <- require_schema_hash(input.tool_name, expected_hash, actual_hash) do
      :ok
    end
  end

  defp verify_schema(_input, _opts, _endpoint_id), do: :ok

  defp find_tool(data, tool_name) do
    tool =
      data
      |> Map.get("tools", Map.get(data, :tools, []))
      |> Enum.find(&(Jido.Connect.Data.get(&1, "name") == tool_name))

    case tool do
      %{} ->
        {:ok, tool}

      nil ->
        {:error,
         Error.validation("MCP tool is not available on the selected endpoint",
           reason: :unknown_mcp_tool,
           subject: tool_name
         )}
    end
  end

  defp require_schema_hash(_tool_name, hash, hash), do: :ok

  defp require_schema_hash(tool_name, expected_hash, actual_hash) do
    {:error,
     Error.validation("MCP tool schema changed before execution",
       reason: :mcp_tool_schema_changed,
       subject: tool_name,
       details: %{expected_schema_hash: expected_hash, actual_schema_hash: actual_hash}
     )}
  end

  defp call_mcp(opts, function, args, nil) do
    client = mcp_client(opts)

    with {:ok, response} <- call_client(client, function, args) do
      normalize_response(response)
    end
  end

  defp call_mcp(opts, function, args, timeout) do
    client = mcp_client(opts)

    with {:ok, response} <- call_client(client, function, args ++ [[timeout: timeout]]) do
      normalize_response(response)
    end
  end

  defp call_client(client, function, args) do
    {:ok, apply(client, function, args)}
  rescue
    exception ->
      {:error,
       Error.provider("MCP request failed",
         provider: :mcp,
         reason: :client_exception,
         details: %{
           module: client,
           function: function,
           message: Exception.message(exception)
         }
       )}
  catch
    kind, reason ->
      {:error,
       Error.provider("MCP request failed",
         provider: :mcp,
         reason: :client_exit,
         details: %{
           module: client,
           function: function,
           kind: kind,
           reason: Jido.Connect.Sanitizer.sanitize(reason, :transport)
         }
       )}
  end

  defp normalize_response(response) do
    case response do
      {:ok, %{status: :ok, data: data}} -> {:ok, data}
      {:ok, %{data: data}} -> {:ok, data}
      {:error, error} -> {:error, normalize_error(error)}
      response -> {:error, invalid_response(response)}
    end
  end

  defp mcp_client(%{credentials: credentials}) do
    Map.get(credentials, :mcp_client) || Map.get(credentials, "mcp_client") || Jido.MCP
  end

  defp timeout(input), do: Map.get(input, :timeout)

  defp normalize_error(%{} = error) do
    Error.provider("MCP request failed",
      provider: :mcp,
      reason: Map.get(error, :type) || Map.get(error, "type"),
      details: error
    )
  end

  defp normalize_error(error) do
    Error.provider("MCP request failed",
      provider: :mcp,
      reason: :mcp_error,
      details: %{error: error}
    )
  end

  defp invalid_response(response) do
    Error.provider("MCP request returned an invalid response",
      provider: :mcp,
      reason: :invalid_response,
      details: %{response: Jido.Connect.Sanitizer.sanitize(response, :transport)}
    )
  end

  defp ensure_dispatchable(%{legacy?: true}), do: :ok
  defp ensure_dispatchable(token), do: EndpointLeaseManager.ensure_dispatchable(token)

  defp dispatch(%{legacy?: true}, fun), do: fun.()

  defp dispatch(token, fun) do
    case EndpointLeaseManager.dispatch(token, fun) do
      {:ok, result, _revoked?} -> result
      {:error, error} -> {:error, error}
    end
  end

  defp release(%{legacy?: true}), do: :ok
  defp release(token), do: EndpointLeaseManager.release(token)
end
