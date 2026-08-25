defmodule Jido.Connect.MCP.ClientSource do
  @moduledoc false

  alias Jido.Connect.{CredentialLease, Error}
  alias Jido.Connect.MCP.{Endpoint, ExMCPClient}

  @enforce_keys [:module, :ownership]
  defstruct [:module, :ref, :endpoint, :ownership]

  @type t :: %__MODULE__{
          module: module(),
          ref: term() | nil,
          endpoint: Endpoint.t() | nil,
          ownership: :host | :connect
        }

  @spec from_lease(String.t(), CredentialLease.t()) :: {:ok, t()} | {:error, Error.error()}
  def from_lease(endpoint_id, %CredentialLease{} = lease) do
    module =
      CredentialLease.get_field(
        lease,
        :mcp_client_module,
        CredentialLease.get_field(lease, :mcp_client, ExMCPClient)
      )

    ref = CredentialLease.get_field(lease, :mcp_client_ref, :missing)
    endpoint = endpoint_from_lease(endpoint_id, lease)

    with :ok <- validate_module(module),
         {:ok, source} <- build(module, ref, endpoint) do
      {:ok, source}
    end
  end

  @spec static(term(), String.t()) :: {:ok, t()} | {:error, term()}
  def static({module, ref}, _endpoint_id), do: static_source(module, ref)

  def static(entry, _endpoint_id) when is_map(entry) or is_list(entry) do
    entry = if is_list(entry), do: Map.new(entry), else: entry
    module = value(entry, :client_module, value(entry, :module, ExMCPClient))
    ref = value(entry, :client_ref, value(entry, :ref, :missing))
    static_source(module, ref)
  rescue
    _error -> {:error, :invalid_client_entry}
  end

  def static(ref, _endpoint_id) when ref != nil, do: static_source(ExMCPClient, ref)
  def static(_entry, _endpoint_id), do: {:error, :invalid_client_entry}

  @spec start(t()) :: {:ok, module(), term(), boolean()} | {:error, term()}
  def start(%__MODULE__{ownership: :host, module: module, ref: ref}),
    do: {:ok, module, ref, false}

  def start(%__MODULE__{ownership: :connect, endpoint: endpoint}) do
    with {:ok, ref} <- ExMCPClient.start_client(endpoint) do
      {:ok, ExMCPClient, ref, true}
    end
  end

  @spec stop(module(), term(), boolean()) :: :ok
  def stop(_module, _ref, false), do: :ok
  def stop(ExMCPClient, ref, true), do: ExMCPClient.stop_client(ref)
  def stop(_module, _ref, true), do: :ok

  @spec fingerprint(t()) :: String.t()
  def fingerprint(%__MODULE__{} = source) do
    projection = %{
      client_module: source.module,
      endpoint: endpoint_projection(source.endpoint),
      ownership: source.ownership
    }

    projection
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp endpoint_from_lease(endpoint_id, lease) do
    case CredentialLease.fetch_field(lease, :mcp_endpoint) do
      {:ok, %Endpoint{} = endpoint} -> {:ok, %{endpoint | id: endpoint_id}}
      {:ok, attrs} -> Endpoint.new(endpoint_id, attrs)
      :error -> :missing
    end
  end

  defp build(_module, ref, {:error, reason}) when ref != :missing,
    do: invalid_endpoint(reason)

  defp build(module, ref, endpoint) when ref != :missing do
    if is_nil(ref) do
      invalid_source(:mcp_client_ref)
    else
      {:ok,
       %__MODULE__{
         module: module,
         ref: ref,
         endpoint: endpoint_value(endpoint),
         ownership: :host
       }}
    end
  end

  defp build(ExMCPClient, :missing, {:ok, %Endpoint{} = endpoint}) do
    {:ok,
     %__MODULE__{
       module: ExMCPClient,
       ref: nil,
       endpoint: endpoint,
       ownership: :connect
     }}
  end

  defp build(_module, :missing, {:error, reason}), do: invalid_endpoint(reason)
  defp build(_module, :missing, :missing), do: invalid_source(:mcp_client_ref)
  defp build(_module, :missing, _endpoint), do: invalid_source(:mcp_endpoint)

  defp static_source(module, ref) do
    with :ok <- validate_module(module),
         true <- ref != :missing and not is_nil(ref) do
      {:ok, %__MODULE__{module: module, ref: ref, endpoint: nil, ownership: :host}}
    else
      _invalid -> {:error, :invalid_client_entry}
    end
  end

  defp validate_module(module) when is_atom(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :list_tools, 2) and
         function_exported?(module, :call_tool, 4) do
      :ok
    else
      invalid_source(:mcp_client_module)
    end
  end

  defp validate_module(_module), do: invalid_source(:mcp_client_module)

  defp endpoint_value({:ok, endpoint}), do: endpoint
  defp endpoint_value(_missing_or_error), do: nil
  defp endpoint_projection(nil), do: nil
  defp endpoint_projection(%Endpoint{} = endpoint), do: Endpoint.identity_projection(endpoint)

  defp invalid_source(key),
    do: {:error, Error.config("MCP client lease field is invalid", key: key)}

  defp invalid_endpoint(reason) do
    {:error,
     Error.config("MCP endpoint lease field is invalid",
       key: :mcp_endpoint,
       details: %{reason: safe_reason(reason)}
     )}
  end

  defp safe_reason(reason) when is_atom(reason), do: reason
  defp safe_reason(reason) when is_tuple(reason) and tuple_size(reason) > 0, do: elem(reason, 0)
  defp safe_reason(_reason), do: :invalid_endpoint

  defp value(map, key, default),
    do: Map.get(map, key, Map.get(map, Atom.to_string(key), default))
end
