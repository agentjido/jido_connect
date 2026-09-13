defmodule Jido.Connect.MCP.Runtime do
  @moduledoc false

  alias Jido.Connect.Error

  alias Jido.Connect.MCP.{
    EndpointLeaseManager,
    EndpointResolver,
    SchemaCompatibility,
    Tool,
    ToolResult
  }

  def list_tools(input, opts) do
    with {:ok, token} <- EndpointResolver.resolve_lease(input.endpoint_id, opts) do
      try do
        with :ok <- ensure_dispatchable(token),
             {:ok, data} <-
               dispatch(token, fn ->
                 call_mcp(token, :list_tools, [], timeout(input))
               end) do
          tools =
            data
            |> Map.get("tools", Map.get(data, :tools, []))
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
  @spec call_typed_tool(map(), map(), keyword()) ::
          {:ok, map()} | {:error, Error.error()}
  def call_typed_tool(input, opts, execution_opts) do
    mutation? = Keyword.fetch!(execution_opts, :mutation?)

    with {:ok, token} <- EndpointResolver.resolve_lease(input.endpoint_id, opts) do
      try do
        with :ok <- ensure_dispatchable(token),
             :ok <- verify_schema(input, opts, token),
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

  defp call_typed(token, _opts, input, true), do: call_write(token, input)

  defp call_typed(token, _opts, input, false) do
    dispatch(token, fn ->
      call_mcp(
        token,
        :call_tool,
        [input.tool_name, input.arguments],
        timeout(input)
      )
    end)
  end

  defp call_write(%{legacy?: true} = token, input) do
    call_mcp(
      token,
      :call_tool,
      [input.tool_name, input.arguments],
      timeout(input)
    )
  end

  defp call_write(token, input) do
    case EndpointLeaseManager.dispatch(token, fn ->
           call_mcp(
             token,
             :call_tool,
             [input.tool_name, input.arguments],
             timeout(input)
           )
         end) do
      {:ok, {:error, error}, revoked?} ->
        if revoked? or uncertain_outcome?(error),
          do: uncertain_write(token),
          else: {:error, error}

      {:ok, result, _revoked?} ->
        result

      {:error, error} ->
        {:error, error}
    end
  end

  defp verify_schema(input, opts, token) do
    expected_hash = Map.get(input, :expected_schema_hash)
    required_schema = Map.get(input, :required_schema)

    if is_nil(expected_hash) and is_nil(required_schema) do
      :ok
    else
      verify_live_schema(input, opts, token, expected_hash, required_schema)
    end
  end

  defp verify_live_schema(input, _opts, token, expected_hash, required_schema) do
    with {:ok, data} <- call_mcp(token, :list_tools, [], timeout(input)),
         {:ok, tool} <- find_tool(data, input.tool_name),
         observed = Tool.from_mcp(tool),
         :ok <- require_schema_hash(input.tool_name, expected_hash, observed.schema_hash),
         :ok <- require_compatible_schema(input.tool_name, required_schema, observed.input_schema),
         :ok <- bind_schema(token, input.tool_name, observed.schema_hash) do
      :ok
    end
  end

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

  defp require_schema_hash(_tool_name, nil, _actual_hash), do: :ok
  defp require_schema_hash(_tool_name, hash, hash), do: :ok

  defp require_schema_hash(tool_name, expected_hash, actual_hash) do
    {:error,
     Error.validation("MCP tool schema changed before execution",
       reason: :mcp_tool_schema_changed,
       subject: tool_name,
       details: %{expected_schema_hash: expected_hash, actual_schema_hash: actual_hash}
     )}
  end

  defp require_compatible_schema(_tool_name, nil, _actual_schema), do: :ok

  defp require_compatible_schema(tool_name, required_schema, actual_schema) do
    if SchemaCompatibility.compatible?(required_schema, actual_schema) do
      :ok
    else
      {:error,
       Error.validation("MCP tool schema changed before execution",
         reason: :mcp_tool_schema_changed,
         subject: tool_name,
         details: %{
           required_schema_hash: Tool.schema_hash(required_schema),
           actual_schema_hash: Tool.schema_hash(actual_schema)
         }
       )}
    end
  end

  defp bind_schema(%{legacy?: true}, _tool_name, _schema_hash), do: :ok

  defp bind_schema(token, tool_name, schema_hash),
    do: EndpointLeaseManager.bind_schema(token, tool_name, schema_hash)

  defp call_mcp(token, function, args, nil) do
    call_args = [token.client_ref | args] ++ [[]]

    with {:ok, response} <- call_client(token.client_module, function, call_args) do
      normalize_response(response)
    end
  end

  defp call_mcp(token, function, args, timeout) do
    call_args = [token.client_ref | args] ++ [[timeout: timeout]]

    with {:ok, response} <- call_client(token.client_module, function, call_args) do
      normalize_response(response)
    end
  end

  defp call_client(client, function, args) do
    {:ok, apply(client, function, args)}
  rescue
    _exception ->
      {:error,
       Error.provider("MCP request failed",
         provider: :mcp,
         reason: :client_exception,
         details: %{
           module: client,
           function: function
         }
       )}
  catch
    _kind, _reason ->
      {:error,
       Error.provider("MCP request failed",
         provider: :mcp,
         reason: :client_exit,
         details: %{
           module: client,
           function: function
         }
       )}
  end

  defp normalize_response(response) do
    case response do
      {:ok, data} when is_map(data) -> {:ok, data}
      {:error, error} -> {:error, normalize_error(error)}
      response -> {:error, invalid_response(response)}
    end
  end

  defp timeout(input), do: Map.get(input, :timeout)

  defp normalize_error(%{} = error) do
    Error.provider("MCP request failed",
      provider: :mcp,
      reason:
        Map.get(error, :reason) || Map.get(error, "reason") || Map.get(error, :type) ||
          Map.get(error, "type") || :mcp_error,
      details: safe_error_details(error)
    )
  end

  defp normalize_error(error) do
    Error.provider("MCP request failed",
      provider: :mcp,
      reason: :mcp_error,
      details: %{error: safe_response_kind(error)}
    )
  end

  defp invalid_response(response) do
    Error.provider("MCP request returned an invalid response",
      provider: :mcp,
      reason: :invalid_response,
      details: %{response: safe_response_kind(response)}
    )
  end

  defp uncertain_outcome?(%Error.ProviderError{reason: :outcome_unknown}), do: true
  defp uncertain_outcome?(_error), do: false

  defp uncertain_write(token) do
    {:error,
     Error.provider("MCP write outcome is uncertain",
       provider: :mcp,
       reason: :mcp_write_uncertain,
       delivery: :sent_outcome_unknown,
       mutation?: true,
       details: %{endpoint_generation: token.generation}
     )}
  end

  defp safe_error_details(error) do
    details = Map.get(error, :details, Map.get(error, "details", %{}))

    %{}
    |> maybe_put(:code, safe_detail(details, :code))
    |> maybe_put(:field, safe_detail(details, :field))
    |> maybe_put(:delivery, safe_detail(details, :delivery))
  end

  defp safe_detail(details, key) when is_map(details) do
    case Map.get(details, key, Map.get(details, Atom.to_string(key))) do
      value when is_atom(value) or is_integer(value) -> value
      value when is_binary(value) and byte_size(value) <= 128 -> value
      _value -> nil
    end
  end

  defp safe_detail(_details, _key), do: nil

  defp safe_response_kind(response) when is_atom(response), do: Atom.to_string(response)
  defp safe_response_kind(response) when is_tuple(response), do: "tuple"
  defp safe_response_kind(response) when is_map(response), do: "map"
  defp safe_response_kind(response) when is_list(response), do: "list"
  defp safe_response_kind(response) when is_binary(response), do: "binary"
  defp safe_response_kind(_response), do: "term"

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

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
