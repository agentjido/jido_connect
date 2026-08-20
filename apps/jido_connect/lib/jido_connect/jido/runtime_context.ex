defmodule Jido.Connect.Jido.RuntimeContext do
  @moduledoc false

  alias Jido.Connect
  alias Jido.Connect.ConnectionSelector
  alias Jido.Connect.Error

  @doc false
  def integration_context(%{integration_context: %Connect.Context{} = context}),
    do: {:ok, context}

  def integration_context(%{context: %Connect.Context{} = context}), do: {:ok, context}

  def integration_context(%{tenant_id: tenant_id, actor: actor} = context) do
    Connect.Context.new(%{
      tenant_id: tenant_id,
      actor: actor,
      connection: Map.get(context, :connection),
      connection_selector: Map.get(context, :connection_selector),
      claims: Map.get(context, :claims, %{}),
      metadata: Map.get(context, :metadata, %{})
    })
  end

  def integration_context(_context), do: {:error, Error.context_required()}

  @doc false
  def resolve_connection(
        %Connect.Context{connection: %Connect.Connection{}} = context,
        _runtime_context,
        _projection,
        _details
      ),
      do: {:ok, context}

  def resolve_connection(
        %Connect.Context{connection_selector: %ConnectionSelector{} = selector} = context,
        runtime_context,
        projection,
        details
      ) do
    resolver = Map.get(runtime_context, :connection_resolver)

    case ConnectionSelector.resolve(selector, resolver, projection, runtime_context) do
      {:ok, %Connect.Connection{} = connection} ->
        if ConnectionSelector.matches_connection?(selector, connection) do
          {:ok, %{context | connection: connection}}
        else
          {:error,
           Error.connection_required(
             Map.merge(details, %{
               connection_selector: selector,
               mismatch: ConnectionSelector.selector_mismatch(selector, connection)
             })
           )}
        end

      {:error, %_{} = error} ->
        {:error, error}

      :error ->
        {:error,
         Error.connection_required(
           Map.merge(details, %{
             connection_selector: selector
           })
         )}
    end
  end

  def resolve_connection(%Connect.Context{} = context, _runtime_context, _projection, _details),
    do: {:ok, context}

  @doc false
  def credential_lease(%{credential_lease: %Connect.CredentialLease{} = lease}),
    do: {:ok, lease}

  def credential_lease(_context), do: {:error, Error.credential_lease_required()}

  @doc false
  def runtime_opts(runtime_context, integration_context, lease, extra \\ %{}) do
    %{
      context: integration_context,
      credential_lease: lease,
      policy: Map.get(runtime_context, :policy),
      policy_context: Map.get(runtime_context, :policy_context, %{}),
      request_timeout_ms: Map.get(runtime_context, :request_timeout_ms)
    }
    |> Map.merge(extra)
  end
end
