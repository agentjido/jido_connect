defmodule Jido.Connect.MCP.EndpointResolver do
  @moduledoc false

  alias Jido.Connect.{Context, CredentialLease, Error}
  alias Jido.Connect.MCP.{ClientSource, EndpointLeaseManager, HostEndpoint}

  @doc """
  Resolves an MCP endpoint identifier to a confirmed client reference.

  A host-owned connection can carry endpoint data in the credential lease.
  Static configurations can name host-supervised clients. Connect does not
  keep a general endpoint pool.
  """
  def resolve(endpoint_id, opts \\ [])

  def resolve(endpoint_id, opts) when is_atom(endpoint_id),
    do: resolve(Atom.to_string(endpoint_id), opts)

  def resolve(endpoint_id, opts) when is_binary(endpoint_id) do
    case resolve_lease(endpoint_id, opts) do
      {:ok, %{endpoint_id: resolved, legacy?: true}} ->
        {:ok, resolved}

      {:ok, %{endpoint_id: resolved} = token} ->
        :ok = EndpointLeaseManager.release(token)
        {:ok, resolved}

      {:ok, resolved} ->
        {:ok, resolved}

      {:error, %_module{} = error} ->
        {:error, error}

      {:error, reason} ->
        {:error,
         Error.validation("Unknown MCP endpoint",
           reason: :unknown_mcp_endpoint,
           subject: endpoint_id,
           details: %{mcp_reason: reason}
         )}
    end
  end

  def resolve(endpoint_id, _opts) do
    {:error,
     Error.validation("Unknown MCP endpoint",
       reason: :unknown_mcp_endpoint,
       subject: endpoint_id,
       details: %{mcp_reason: :invalid_endpoint_id}
     )}
  end

  @doc false
  @spec resolve_lease(atom() | String.t(), keyword() | map()) ::
          {:ok, EndpointLeaseManager.token() | %{endpoint_id: atom() | String.t(), legacy?: true}}
          | {:error, Error.error()}
  def resolve_lease(endpoint_id, opts \\ [])

  def resolve_lease(endpoint_id, opts) when is_atom(endpoint_id),
    do: resolve_lease(Atom.to_string(endpoint_id), opts)

  def resolve_lease(endpoint_id, opts) when is_binary(endpoint_id) do
    case do_resolve_lease(endpoint_id, opts) do
      {:ok, resolved} ->
        {:ok, resolved}

      {:error, %_module{} = error} ->
        {:error, error}

      {:error, reason} ->
        {:error,
         Error.validation("Unknown MCP endpoint",
           reason: :unknown_mcp_endpoint,
           subject: endpoint_id,
           details: %{mcp_reason: reason}
         )}
    end
  end

  def resolve_lease(endpoint_id, _opts) do
    {:error,
     Error.validation("Unknown MCP endpoint",
       reason: :unknown_mcp_endpoint,
       subject: endpoint_id,
       details: %{mcp_reason: :invalid_endpoint_id}
     )}
  end

  # -- private ----------------------------------------------------------------

  defp do_resolve_lease(endpoint_id, opts) do
    case host_context(opts) do
      {:ok, context, lease} ->
        with {:ok, _public_id, endpoint} <-
               HostEndpoint.endpoint(endpoint_id, context.connection, lease) do
          EndpointLeaseManager.acquire(context.connection, lease, endpoint)
        end

      :legacy ->
        with {:ok, resolved, source} <- resolve_static(endpoint_id) do
          {:ok,
           %{
             endpoint_id: resolved,
             client_module: source.module,
             client_ref: source.ref,
             legacy?: true
           }}
        end
    end
  end

  defp host_context(%{
         context: %Context{} = context,
         credential_lease: %CredentialLease{} = lease
       }) do
    if context.connection && client_source?(lease), do: {:ok, context, lease}, else: :legacy
  end

  defp host_context(opts) when is_list(opts), do: opts |> Map.new() |> host_context()

  defp host_context(_opts), do: :legacy

  defp resolve_static(endpoint_id) do
    trimmed = String.trim(endpoint_id)

    cond do
      trimmed == "" ->
        {:error, :invalid_endpoint_id}

      true ->
        clients = static_clients()

        case Enum.find(Map.keys(clients), &(endpoint_key(&1) == trimmed)) do
          nil ->
            {:error, :unknown_endpoint}

          id ->
            with {:ok, source} <- ClientSource.static(Map.fetch!(clients, id), trimmed) do
              {:ok, id, source}
            end
        end
    end
  end

  defp static_clients do
    :jido_connect
    |> Application.get_env(:mcp_clients, %{})
    |> to_map()
  end

  defp client_source?(lease) do
    Enum.any?([:mcp_endpoint, :mcp_client_ref], fn key ->
      match?({:ok, _value}, CredentialLease.fetch_field(lease, key))
    end)
  end

  defp to_map(endpoints) when is_map(endpoints), do: endpoints
  defp to_map(endpoints) when is_list(endpoints), do: Enum.into(endpoints, %{})
  defp to_map(_), do: %{}

  defp endpoint_key(key) when is_atom(key), do: Atom.to_string(key)
  defp endpoint_key(key) when is_binary(key), do: key
  defp endpoint_key(_key), do: nil
end
