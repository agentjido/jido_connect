defmodule Jido.Connect.MCP.ExMCPClient do
  @moduledoc false

  @behaviour Jido.Connect.MCP.Client

  alias ExMCP.Error
  alias Jido.Connect.MCP.{ClientSupervisor, Endpoint}

  @protected_client_options [
    :capabilities,
    :cd,
    :command,
    :endpoint,
    :env,
    :fallback_strategy,
    :handshake_timeout,
    :headers,
    :health_check_interval,
    :max_reconnect_attempts,
    :max_retries,
    :name,
    :protocol_version,
    :reconnect,
    :reconnect_backoff,
    :reliability,
    :request_timeout,
    :retry_interval,
    :retry_policy,
    :server,
    :timeout,
    :transport,
    :transports,
    :url,
    :use_sse
  ]

  @finite_timeout_options [
    :timeout,
    :request_timeout,
    :handshake_timeout,
    :stream_handshake_timeout,
    :stream_idle_timeout,
    :dns_timeout_ms,
    :max_retry_delay
  ]

  @protected_transport_options [
    :fallback_strategy,
    :health_check_interval,
    :http_stream_retry,
    :max_reconnect_attempts,
    :max_retries,
    :reconnect,
    :reconnect_backoff,
    :reliability,
    :retry_interval,
    :retry_policy,
    :retry_safe
  ]

  @spec start_client(Endpoint.t()) :: {:ok, pid()} | {:error, term()}
  def start_client(%Endpoint{} = endpoint) do
    with {:ok, opts} <- client_options(endpoint) do
      spec = Supervisor.child_spec({ExMCP.Client, opts}, restart: :temporary)

      case DynamicSupervisor.start_child(ClientSupervisor, spec) do
        {:ok, pid} -> {:ok, pid}
        {:ok, pid, _info} -> {:ok, pid}
        {:error, reason} -> {:error, sanitize_start_error(reason)}
      end
    end
  end

  @spec stop_client(term()) :: :ok
  def stop_client(ref) when is_pid(ref) do
    case DynamicSupervisor.terminate_child(ClientSupervisor, ref) do
      :ok -> :ok
      {:error, :not_found} -> :ok
    end
  catch
    :exit, _reason -> :ok
  end

  def stop_client(_ref), do: :ok

  @impl true
  def list_tools(client, opts) do
    request(fn ->
      with {:ok, request_opts} <- request_opts(opts, false) do
        ExMCP.Client.list_tools(client, request_opts)
      end
    end)
  end

  @impl true
  def call_tool(client, tool_name, arguments, opts) do
    request(fn ->
      with {:ok, request_opts} <- request_opts(opts, true) do
        ExMCP.Client.call_tool(client, tool_name, arguments, request_opts)
      end
    end)
  end

  @doc false
  @spec client_options(Endpoint.t()) :: {:ok, keyword()} | {:error, term()}
  def client_options(%Endpoint{} = endpoint) do
    with :ok <- validate_client_options(endpoint.client_options),
         :ok <- validate_transport_options(endpoint.transport),
         {:ok, transport_opts} <- transport_options(endpoint.transport),
         :ok <- validate_finite_timeouts(transport_opts) do
      opts =
        [
          capabilities: endpoint.capabilities,
          protocol_version: endpoint.protocol_version,
          protocol_mode: protocol_mode(endpoint.protocol_version),
          timeout: endpoint.timeouts.request_ms,
          request_timeout: endpoint.timeouts.request_ms,
          handshake_timeout: endpoint.timeouts.request_ms,
          health_check_interval: nil,
          reconnect: false,
          retry_policy: []
        ]
        |> Keyword.merge(transport_opts)
        |> Keyword.merge(endpoint.client_options)
        |> Keyword.put(:transport, transport_opts[:transport])
        |> Keyword.put(:capabilities, endpoint.capabilities)
        |> Keyword.put(:protocol_version, endpoint.protocol_version)
        |> Keyword.put(:timeout, endpoint.timeouts.request_ms)
        |> Keyword.put(:request_timeout, endpoint.timeouts.request_ms)
        |> Keyword.put(:handshake_timeout, endpoint.timeouts.request_ms)
        |> Keyword.put(:health_check_interval, nil)
        |> Keyword.put(:reconnect, false)
        |> Keyword.put(:retry_policy, [])

      {:ok, opts}
    end
  end

  defp transport_options({:stdio, opts}) do
    command = Keyword.get(opts, :command)
    args = Keyword.get(opts, :args, []) || []

    with {:ok, command} <- stdio_command(command, args),
         {:ok, cwd} <- stdio_cwd(Keyword.get(opts, :cwd)),
         {:ok, env} <- stdio_env(Keyword.get(opts, :env)) do
      mapped =
        opts
        |> Keyword.drop([:args, :cwd, :command, :env])
        |> Keyword.put(:transport, :stdio)
        |> Keyword.put(:command, command)
        |> maybe_put(:cd, cwd)
        |> maybe_put(:env, env)

      {:ok, mapped}
    end
  end

  defp transport_options({:streamable_http, opts}) do
    base_url = Keyword.get(opts, :base_url)
    mcp_path = Keyword.get(opts, :mcp_path, "/mcp")
    headers = Keyword.get(opts, :headers, [])

    with :ok <- validate_http_base_url(base_url),
         :ok <- validate_mcp_path(mcp_path),
         :ok <- validate_headers(headers) do
      mapped =
        opts
        |> Keyword.drop([:base_url, :mcp_path, :enable_sse, :finch_name])
        |> Keyword.put(:transport, :http)
        |> Keyword.put(:url, base_url)
        |> Keyword.put(:endpoint, mcp_path)
        |> maybe_put(:use_sse, Keyword.get(opts, :enable_sse))

      {:ok, mapped}
    end
  end

  defp transport_options({:beam, opts}) do
    case Keyword.get(opts, :server) do
      server when is_pid(server) ->
        if Process.alive?(server),
          do: {:ok, Keyword.put(opts, :transport, :beam)},
          else: {:error, {:invalid_transport_options, :server}}

      _server ->
        {:error, {:invalid_transport_options, :server}}
    end
  end

  defp transport_options({transport, _opts}),
    do: {:error, {:unsupported_transport, transport, :ex_mcp}}

  defp request_opts(opts, tool?) when is_list(opts) do
    if Keyword.keyword?(opts) and valid_timeout?(Keyword.get(opts, :timeout)) do
      request_opts =
        opts
        |> Keyword.take([:timeout])
        |> Keyword.put(:format, :map)
        |> Keyword.put(:retry_policy, false)
        |> Keyword.put(:http_stream_retry, :safe_only)

      request_opts =
        if tool?, do: Keyword.put(request_opts, :retry_safe, false), else: request_opts

      {:ok, request_opts}
    else
      {:error, {:invalid_request_option, :options}}
    end
  end

  defp request_opts(_opts, _tool?), do: {:error, {:invalid_request_option, :options}}

  defp request(fun) do
    fun.()
    |> sanitize_result()
  rescue
    _exception -> {:error, public_error(:request_failed)}
  catch
    _kind, _reason -> {:error, public_error(:request_failed)}
  end

  defp sanitize_result({:ok, response}) when is_map(response),
    do: {:ok, stringify_keys(response)}

  defp sanitize_result({:error, reason}), do: {:error, public_error(reason)}
  defp sanitize_result(_response), do: {:error, public_error(:invalid_response)}

  defp public_error(%Error.TransportError{reason: :outcome_unknown}) do
    %{reason: :outcome_unknown, details: %{delivery: :unknown}}
  end

  defp public_error(%Error.TransportError{reason: reason}) do
    %{reason: safe_transport_reason(reason), details: %{}}
  end

  defp public_error(%Error.ProtocolError{code: code}), do: protocol_error(code)

  defp public_error(%Error.ValidationError{field: field}) do
    %{reason: :invalid_params, details: %{field: safe_field(field)}}
  end

  defp public_error(%Error.ToolError{}), do: %{reason: :tool_error, details: %{}}
  defp public_error(%Error.ResourceError{}), do: %{reason: :protocol_error, details: %{}}
  defp public_error(%Error{code: code}), do: protocol_error(code)
  defp public_error(%{"code" => code}) when is_integer(code), do: protocol_error(code)

  defp public_error({:invalid_request_option, field}),
    do: %{reason: :invalid_params, details: %{field: safe_field(field)}}

  defp public_error(reason) when reason in [:timeout, :cancelled, :not_connected],
    do: %{reason: reason, details: %{}}

  defp public_error(_reason), do: %{reason: :request_failed, details: %{}}

  defp protocol_error(code) when is_integer(code),
    do: %{reason: protocol_reason(code), details: %{code: code}}

  defp protocol_error(_code), do: %{reason: :protocol_error, details: %{}}

  defp protocol_reason(-32_700), do: :parse_error
  defp protocol_reason(-32_600), do: :invalid_request
  defp protocol_reason(-32_601), do: :method_not_found
  defp protocol_reason(-32_602), do: :invalid_params
  defp protocol_reason(_code), do: :protocol_error

  defp sanitize_start_error({:invalid_transport_options, field}),
    do: {:invalid_transport_options, safe_field(field)}

  defp sanitize_start_error({:unsupported_transport, transport, :ex_mcp}),
    do: {:unsupported_transport, transport, :ex_mcp}

  defp sanitize_start_error({:protected_client_option, option}),
    do: {:protected_client_option, option}

  defp sanitize_start_error(:handshake_timeout), do: :client_not_ready
  defp sanitize_start_error({:connection_error, _details}), do: :connection_failed
  defp sanitize_start_error(_reason), do: :client_start_failed

  defp validate_client_options(opts) do
    case Enum.find(Keyword.keys(opts), &(&1 in @protected_client_options)) do
      nil -> :ok
      option -> {:error, {:protected_client_option, option}}
    end
  end

  defp validate_transport_options({_transport, opts}) do
    case Enum.find(Keyword.keys(opts), &(&1 in @protected_transport_options)) do
      nil -> :ok
      option -> {:error, {:protected_client_option, option}}
    end
  end

  defp validate_finite_timeouts(opts) do
    case Enum.find(@finite_timeout_options, fn key ->
           Keyword.has_key?(opts, key) and not positive_integer?(opts[key])
         end) do
      nil -> :ok
      option -> {:error, {:invalid_transport_options, option}}
    end
  end

  defp validate_http_base_url(base_url) when is_binary(base_url) and base_url != "" do
    case URI.new(base_url) do
      {:ok,
       %URI{scheme: scheme, host: host, userinfo: nil, query: nil, fragment: nil, path: path}}
      when scheme in ["http", "https"] and is_binary(host) and host != "" and
             path in [nil, "", "/"] ->
        :ok

      _invalid ->
        {:error, {:invalid_transport_options, :base_url}}
    end
  end

  defp validate_http_base_url(_base_url),
    do: {:error, {:invalid_transport_options, :base_url}}

  defp validate_mcp_path("/" <> _rest), do: :ok
  defp validate_mcp_path(_path), do: {:error, {:invalid_transport_options, :mcp_path}}

  defp validate_headers(headers) when is_list(headers) do
    if Enum.all?(headers, fn
         {name, value} when is_binary(name) and is_binary(value) -> true
         _header -> false
       end),
       do: :ok,
       else: {:error, {:invalid_transport_options, :headers}}
  end

  defp validate_headers(_headers), do: {:error, {:invalid_transport_options, :headers}}

  defp stdio_command(command, args) when is_binary(command) and is_list(args),
    do: valid_command([command | args])

  defp stdio_command(command, args) when is_list(command) and is_list(args),
    do: valid_command(command ++ args)

  defp stdio_command(_command, _args), do: {:error, {:invalid_transport_options, :command}}

  defp valid_command([executable | _rest] = command)
       when is_binary(executable) and executable != "" do
    if Enum.all?(command, &(is_binary(&1) and not String.contains?(&1, <<0>>))),
      do: {:ok, command},
      else: {:error, {:invalid_transport_options, :command}}
  end

  defp valid_command(_command), do: {:error, {:invalid_transport_options, :command}}

  defp stdio_cwd(nil), do: {:ok, nil}

  defp stdio_cwd(cwd) when is_binary(cwd) and cwd != "" do
    if String.contains?(cwd, <<0>>),
      do: {:error, {:invalid_transport_options, :cwd}},
      else: {:ok, cwd}
  end

  defp stdio_cwd(_cwd), do: {:error, {:invalid_transport_options, :cwd}}

  defp stdio_env(nil), do: {:ok, nil}

  defp stdio_env(env) when is_map(env),
    do: env |> Map.to_list() |> stdio_env()

  defp stdio_env(env) when is_list(env) do
    if Enum.all?(env, fn
         {name, value}
         when (is_binary(name) or is_atom(name)) and (is_binary(value) or value == false) ->
           name = to_string(name)
           name != "" and not String.contains?(name, ["=", <<0>>])

         _entry ->
           false
       end) do
      {:ok, Enum.map(env, fn {name, value} -> {to_string(name), value} end)}
    else
      {:error, {:invalid_transport_options, :env}}
    end
  end

  defp stdio_env(_env), do: {:error, {:invalid_transport_options, :env}}

  defp protocol_mode("2026-" <> _rest), do: :modern_only
  defp protocol_mode(_version), do: :legacy_only
  defp valid_timeout?(nil), do: true
  defp valid_timeout?(timeout), do: positive_integer?(timeout)
  defp positive_integer?(value), do: is_integer(value) and value > 0

  defp safe_transport_reason(reason) when reason in [:closed, :timeout, :not_connected],
    do: reason

  defp safe_transport_reason(_reason), do: :transport_error
  defp safe_field(field) when is_atom(field) or is_binary(field), do: field
  defp safe_field(_field), do: :request
  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp stringify_keys(value) when is_map(value) do
    Map.new(value, fn {key, item} -> {string_key(key), stringify_keys(item)} end)
  end

  defp stringify_keys(value) when is_list(value), do: Enum.map(value, &stringify_keys/1)
  defp stringify_keys(value), do: value
  defp string_key(key) when is_atom(key), do: Atom.to_string(key)
  defp string_key(key), do: key
end
