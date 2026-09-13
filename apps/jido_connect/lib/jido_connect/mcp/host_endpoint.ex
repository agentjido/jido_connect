defmodule Jido.Connect.MCP.HostEndpoint do
  @moduledoc false

  alias Jido.Connect.{Connection, CredentialLease, Data, Error}
  alias Jido.Connect.MCP.{ClientSource, EndpointLeaseManager}

  @id_prefix "jido-connect:"

  @spec resolve(atom() | String.t(), Connection.t(), CredentialLease.t()) ::
          {:ok, String.t(), String.t()} | {:error, Error.error()}
  def resolve(requested_id, %Connection{} = connection, %CredentialLease{} = lease) do
    with {:ok, public_id, endpoint} <- endpoint(requested_id, connection, lease),
         {:ok, token} <- EndpointLeaseManager.acquire(connection, lease, endpoint) do
      :ok = EndpointLeaseManager.release(token)
      {:ok, public_id, token.endpoint_id}
    end
  end

  @doc false
  @spec endpoint(atom() | String.t(), Connection.t(), CredentialLease.t()) ::
          {:ok, String.t(), ClientSource.t()} | {:error, Error.error()}
  def endpoint(requested_id, %Connection{} = connection, %CredentialLease{} = lease) do
    with {:ok, public_id} <- require_public_id(requested_id, connection),
         {:ok, source} <- ClientSource.from_lease(internal_id(connection), lease) do
      {:ok, public_id, source}
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

  defp normalize_id(id) when is_atom(id), do: Atom.to_string(id)
  defp normalize_id(id) when is_binary(id), do: String.trim(id)
  defp normalize_id(_id), do: nil
end
