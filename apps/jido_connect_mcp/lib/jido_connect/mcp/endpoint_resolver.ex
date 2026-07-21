defmodule Jido.Connect.MCP.EndpointResolver do
  @moduledoc false

  alias Jido.Connect.Error

  @doc """
  Resolves an MCP endpoint identifier (atom or binary) to a confirmed
  endpoint atom.

  When `Jido.MCP.ClientPool` is loaded (the `jido_mcp` application has been
  compiled), resolution delegates to the ClientPool GenServer so that
  runtime-registered endpoints are visible.  Otherwise falls back to reading
  the raw `:endpoints` config from the `:jido_mcp` application environment.
  """
  def resolve(endpoint_id) when is_atom(endpoint_id), do: resolve(Atom.to_string(endpoint_id))

  def resolve(endpoint_id) when is_binary(endpoint_id) do
    case do_resolve(endpoint_id) do
      {:ok, resolved} ->
        {:ok, resolved}

      {:error, reason} ->
        {:error,
         Error.validation("Unknown MCP endpoint",
           reason: :unknown_mcp_endpoint,
           subject: endpoint_id,
           details: %{mcp_reason: reason}
         )}
    end
  end

  # -- private ----------------------------------------------------------------

  defp do_resolve(endpoint_id) do
    client_pool = Module.concat(Jido.MCP, ClientPool)

    if Code.ensure_loaded?(client_pool) and
         function_exported?(client_pool, :resolve_endpoint_id, 1) do
      apply(client_pool, :resolve_endpoint_id, [endpoint_id])
    else
      resolve_from_config(endpoint_id)
    end
  end

  defp resolve_from_config(endpoint_id) do
    trimmed = String.trim(endpoint_id)

    cond do
      trimmed == "" ->
        {:error, :invalid_endpoint_id}

      true ->
        endpoints = raw_endpoints()

        case Enum.find(Map.keys(endpoints), &(Atom.to_string(&1) == trimmed)) do
          nil -> {:error, :unknown_endpoint}
          id -> {:ok, id}
        end
    end
  end

  defp raw_endpoints do
    :jido_mcp
    |> Application.get_env(:endpoints, %{})
    |> to_map()
  end

  defp to_map(endpoints) when is_map(endpoints), do: endpoints
  defp to_map(endpoints) when is_list(endpoints), do: Enum.into(endpoints, %{})
  defp to_map(_), do: %{}
end
