defmodule Jido.Connect.MCP.HostEndpoint do
  @moduledoc false

  alias Jido.Connect.{Connection, CredentialLease, Data, Error, Sanitizer}
  alias Jido.MCP.{ClientPool, Endpoint}

  @id_prefix "jido-connect:"

  @spec resolve(atom() | String.t(), Connection.t(), CredentialLease.t()) ::
          {:ok, String.t(), String.t()} | {:error, Error.error()}
  def resolve(requested_id, %Connection{} = connection, %CredentialLease{} = lease) do
    with {:ok, public_id} <- require_public_id(requested_id, connection),
         {:ok, endpoint_source} <- fetch_endpoint_source(lease),
         internal_id = internal_id(connection),
         {:ok, endpoint} <- build_endpoint(internal_id, endpoint_source),
         :ok <- reconcile_endpoint(internal_id, endpoint) do
      {:ok, public_id, internal_id}
    end
  end

  @doc false
  @spec internal_id(Connection.t()) :: String.t()
  def internal_id(%Connection{} = connection) do
    digest =
      :crypto.hash(:sha256, :erlang.term_to_binary({connection.tenant_id, connection.id}))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 32)

    @id_prefix <> digest
  end

  defp require_public_id(requested_id, connection) do
    requested_id = normalize_id(requested_id)
    expected_id = Data.get(connection.metadata, :mcp_endpoint_id, connection.id)
    expected_id = normalize_id(expected_id)

    cond do
      requested_id in [nil, ""] ->
        {:error,
         Error.validation("MCP endpoint id is invalid",
           reason: :invalid_mcp_endpoint,
           subject: requested_id
         )}

      expected_id in [nil, ""] ->
        {:error,
         Error.config("MCP connection does not declare an endpoint id",
           key: :mcp_endpoint_id
         )}

      requested_id != expected_id ->
        {:error,
         Error.auth("MCP endpoint does not match the selected connection",
           reason: :mcp_endpoint_connection_mismatch,
           connection_id: connection.id,
           details: %{requested_endpoint_id: requested_id}
         )}

      true ->
        {:ok, requested_id}
    end
  end

  defp fetch_endpoint_source(lease) do
    case CredentialLease.fetch_field(lease, :mcp_endpoint) do
      {:ok, source} -> {:ok, source}
      :error -> {:error, Error.config("MCP endpoint lease field is required", key: :mcp_endpoint)}
    end
  end

  defp build_endpoint(internal_id, %Endpoint{} = endpoint) do
    internal_id
    |> Endpoint.new(Map.from_struct(endpoint))
    |> normalize_endpoint_result()
  end

  defp build_endpoint(internal_id, attrs) when is_map(attrs) or is_list(attrs) do
    internal_id
    |> Endpoint.new(attrs)
    |> normalize_endpoint_result()
  end

  defp build_endpoint(_internal_id, _source) do
    {:error, Error.config("MCP endpoint lease field is invalid", key: :mcp_endpoint)}
  end

  defp normalize_endpoint_result({:ok, %Endpoint{} = endpoint}), do: {:ok, endpoint}

  defp normalize_endpoint_result({:error, reason}) do
    {:error,
     Error.config("MCP endpoint lease field is invalid",
       key: :mcp_endpoint,
       details: %{reason: safe_reason(reason)}
     )}
  end

  defp reconcile_endpoint(internal_id, endpoint) do
    case :global.trans({__MODULE__, internal_id}, fn -> do_reconcile(internal_id, endpoint) end) do
      :ok ->
        :ok

      {:error, %_module{} = error} ->
        {:error, error}

      {:aborted, reason} ->
        {:error,
         Error.execution("MCP endpoint registration lock failed",
           phase: :endpoint_registration,
           details: %{reason: Sanitizer.sanitize(reason, :transport)}
         )}
    end
  end

  defp do_reconcile(internal_id, endpoint) do
    case ClientPool.fetch_endpoint(internal_id) do
      {:ok, ^endpoint} ->
        :ok

      {:ok, _existing} ->
        with {:ok, _removed} <- Jido.MCP.unregister_endpoint(internal_id),
             {:ok, _registered} <- Jido.MCP.register_endpoint(endpoint) do
          :ok
        else
          {:error, reason} -> registration_error(reason)
        end

      {:error, :unknown_endpoint} ->
        case Jido.MCP.register_endpoint(endpoint) do
          {:ok, _registered} -> :ok
          {:error, reason} -> registration_error(reason)
        end

      {:error, reason} ->
        registration_error(reason)
    end
  end

  defp registration_error(reason) do
    {:error,
     Error.execution("MCP endpoint registration failed",
       phase: :endpoint_registration,
       details: %{reason: safe_reason(reason)}
     )}
  end

  defp safe_reason(reason) when is_atom(reason), do: reason
  defp safe_reason(reason) when is_tuple(reason), do: elem(reason, 0)
  defp safe_reason(_reason), do: :invalid_endpoint

  defp normalize_id(id) when is_atom(id), do: Atom.to_string(id)
  defp normalize_id(id) when is_binary(id), do: String.trim(id)
  defp normalize_id(_id), do: nil
end
