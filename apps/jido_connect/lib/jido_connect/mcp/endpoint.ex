defmodule Jido.Connect.MCP.Endpoint do
  @moduledoc """
  A validated connection-scoped MCP client definition.

  This value describes one ExMCP client. It is not an endpoint registry and it
  does not contain a public endpoint ID.
  """

  @default_protocol_version "2025-06-18"
  @default_request_timeout_ms 30_000
  @max_endpoint_id_bytes 255

  @type id :: atom() | String.t()
  @type transport ::
          {:stdio, keyword()}
          | {:streamable_http, keyword()}
          | {:beam, keyword()}

  @type t :: %__MODULE__{
          id: id(),
          client_options: keyword(),
          transport: transport(),
          client_info: %{required(String.t()) => String.t()},
          protocol_version: String.t(),
          capabilities: map(),
          timeouts: %{request_ms: pos_integer()}
        }

  @enforce_keys [:id, :transport, :client_info, :protocol_version, :capabilities, :timeouts]
  defstruct [
    :id,
    :transport,
    :client_info,
    :protocol_version,
    :capabilities,
    :timeouts,
    client_options: []
  ]

  @spec new(id(), map() | keyword()) :: {:ok, t()} | {:error, term()}
  def new(id, attrs) when (is_atom(id) or is_binary(id)) and is_list(attrs) do
    if Keyword.keyword?(attrs), do: new(id, Map.new(attrs)), else: invalid_id(id)
  end

  def new(id, attrs) when (is_atom(id) or is_binary(id)) and is_map(attrs) do
    with :ok <- validate_id(id),
         :ok <- validate_backend_marker(attrs),
         {:ok, client_options} <- validate_client_options(value(attrs, :client_options, [])),
         {:ok, transport} <- validate_transport(value(attrs, :transport)),
         {:ok, client_info} <- validate_client_info(value(attrs, :client_info)),
         {:ok, protocol_version} <- validate_protocol(value(attrs, :protocol_version)),
         {:ok, capabilities} <- validate_capabilities(value(attrs, :capabilities, %{})),
         {:ok, timeouts} <- validate_timeouts(value(attrs, :timeouts, %{})) do
      {:ok,
       %__MODULE__{
         id: id,
         client_options: client_options,
         transport: transport,
         client_info: client_info,
         protocol_version: protocol_version,
         capabilities: capabilities,
         timeouts: timeouts
       }}
    end
  end

  def new(id, _attrs), do: invalid_id(id)

  @doc false
  @spec identity_projection(t()) :: map()
  def identity_projection(%__MODULE__{} = endpoint) do
    %{
      transport: transport_projection(endpoint.transport),
      protocol_version: endpoint.protocol_version,
      capabilities: endpoint.capabilities,
      request_timeout_ms: endpoint.timeouts.request_ms,
      client_name: endpoint.client_info["name"]
    }
  end

  defp validate_transport({:stdio, opts}), do: validate_transport_opts(:stdio, opts)
  defp validate_transport({:shell, opts}), do: validate_transport_opts(:stdio, opts)

  defp validate_transport({:sse, _opts}),
    do: {:error, {:unsupported_transport, :sse, :ex_mcp}}

  defp validate_transport({:streamable_http, opts}),
    do: validate_transport_opts(:streamable_http, opts)

  defp validate_transport({:beam, opts}), do: validate_transport_opts(:beam, opts)

  defp validate_transport(other), do: {:error, {:invalid_transport, kind(other)}}

  defp validate_transport_opts(_transport, opts) when not is_list(opts),
    do: {:error, {:invalid_transport_options, :options}}

  defp validate_transport_opts(transport, opts) do
    if Keyword.keyword?(opts) do
      {:ok, {transport, normalize_transport_opts(transport, opts)}}
    else
      {:error, {:invalid_transport_options, :options}}
    end
  end

  defp normalize_transport_opts(:streamable_http, opts) do
    opts
    |> normalize_streamable_http_url()
    |> normalize_streamable_http_base_url()
  end

  defp normalize_transport_opts(_transport, opts), do: opts

  defp normalize_streamable_http_url(opts) do
    case Keyword.pop(opts, :url) do
      {nil, opts} -> opts
      {url, opts} when is_binary(url) -> put_url_parts(opts, url)
      {_url, opts} -> Keyword.put(opts, :base_url, :invalid)
    end
  end

  defp normalize_streamable_http_base_url(opts) do
    base_url = Keyword.get(opts, :base_url)

    if is_binary(base_url) and not Keyword.has_key?(opts, :mcp_path) and pathful_url?(base_url) do
      put_url_parts(Keyword.delete(opts, :base_url), base_url)
    else
      opts
    end
  end

  defp put_url_parts(opts, url) do
    uri = URI.parse(url)

    opts
    |> Keyword.put(:base_url, base_uri(uri))
    |> Keyword.put(:mcp_path, endpoint_path(uri))
  end

  defp pathful_url?(url) do
    case URI.parse(url).path do
      path when is_binary(path) and path not in ["", "/"] -> true
      _path -> false
    end
  end

  defp endpoint_path(%URI{} = uri) do
    path = if is_binary(uri.path) and uri.path != "", do: uri.path, else: "/mcp"

    if is_binary(uri.query) and uri.query != "", do: path <> "?" <> uri.query, else: path
  end

  defp base_uri(%URI{} = uri) do
    uri
    |> Map.put(:path, nil)
    |> Map.put(:query, nil)
    |> Map.put(:fragment, nil)
    |> URI.to_string()
  end

  defp validate_id(id) when is_atom(id), do: :ok

  defp validate_id(id) when is_binary(id) do
    if String.valid?(id) and byte_size(id) <= @max_endpoint_id_bytes and id != "" and
         String.trim(id) == id and not String.match?(id, ~r/[\x00-\x1F\x7F]/u) do
      :ok
    else
      invalid_id(id)
    end
  end

  defp validate_backend_marker(attrs) do
    case value(attrs, :backend) do
      nil -> :ok
      backend when backend in [:ex_mcp, "ex_mcp"] -> :ok
      backend -> {:error, {:unsupported_backend, kind(backend), :ex_mcp}}
    end
  end

  defp validate_client_options(opts) when is_list(opts) do
    if Keyword.keyword?(opts),
      do: {:ok, opts},
      else: {:error, {:invalid_client_options, :options}}
  end

  defp validate_client_options(_opts), do: {:error, {:invalid_client_options, :options}}

  defp validate_client_info(info) when is_map(info) do
    name = value(info, :name)
    version = value(info, :version, "1.0.0")

    if is_binary(name) and name != "" do
      {:ok, %{"name" => name, "version" => to_string(version)}}
    else
      {:error, {:invalid_client_info, :name}}
    end
  end

  defp validate_client_info(_info), do: {:error, {:invalid_client_info, :name}}

  defp validate_protocol(nil), do: {:ok, @default_protocol_version}
  defp validate_protocol(version) when is_binary(version) and version != "", do: {:ok, version}
  defp validate_protocol(_version), do: {:error, {:invalid_protocol_version, :version}}

  defp validate_capabilities(capabilities) when is_map(capabilities), do: {:ok, capabilities}
  defp validate_capabilities(nil), do: {:ok, %{}}
  defp validate_capabilities(_capabilities), do: {:error, {:invalid_capabilities, :capabilities}}

  defp validate_timeouts(timeouts) when is_map(timeouts) do
    request_ms = value(timeouts, :request_ms, @default_request_timeout_ms)

    if is_integer(request_ms) and request_ms > 0,
      do: {:ok, %{request_ms: request_ms}},
      else: {:error, {:invalid_timeouts, :request_ms}}
  end

  defp validate_timeouts(nil), do: {:ok, %{request_ms: @default_request_timeout_ms}}
  defp validate_timeouts(_timeouts), do: {:error, {:invalid_timeouts, :timeouts}}

  defp transport_projection({:streamable_http, opts}) do
    %{
      type: :streamable_http,
      base_url: Keyword.get(opts, :base_url),
      mcp_path: Keyword.get(opts, :mcp_path)
    }
  end

  defp transport_projection({type, _opts}), do: %{type: type}

  defp value(map, key, default \\ nil),
    do: Map.get(map, key, Map.get(map, Atom.to_string(key), default))

  defp invalid_id(_id), do: {:error, {:invalid_endpoint_id, :id}}
  defp kind(value) when is_atom(value), do: value
  defp kind(value) when is_tuple(value) and tuple_size(value) > 0, do: elem(value, 0)
  defp kind(_value), do: :invalid
end
