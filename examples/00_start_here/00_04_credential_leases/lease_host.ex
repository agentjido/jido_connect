defmodule Jido.Connect.Examples.StartHere.LeaseHost do
  @moduledoc "An in-memory host that keeps credentials separate from connection grants."
  @behaviour Jido.Connect.CredentialResolver

  alias Jido.Connect.{Connection, Context, CredentialLease, Error}

  defmodule Credential do
    @moduledoc false
    @enforce_keys [:access_token, :scopes]
    defstruct [:access_token, :scopes, version: 1]
  end

  def start_link(credentials, grants, github_client) do
    Agent.start_link(fn ->
      %{
        credentials: credentials,
        grants: Map.new(grants, &{connection_key(&1.connection), &1}),
        github_client: github_client
      }
    end)
  end

  def binding(store, %Connection{} = connection, actor) do
    Context.new!(%{
      tenant_id: connection.tenant_id,
      actor: actor,
      connection: connection,
      metadata: %{lease_store: store},
      policy: __MODULE__
    })
  end

  def rotate_credential(store, key, token) do
    Agent.get_and_update(store, fn state ->
      case Map.fetch(state.credentials, key) do
        {:ok, credential} ->
          next = %{credential | access_token: token, version: credential.version + 1}
          {:ok, put_in(state.credentials[key], next)}

        :error ->
          {{:error, :credential_unavailable}, state}
      end
    end)
  end

  def revoke_grant(store, %Connection{} = connection) do
    Agent.update(
      store,
      &update_in(&1.grants, fn grants -> Map.delete(grants, connection_key(connection)) end)
    )
  end

  def revoke_credential(store, key) do
    Agent.update(
      store,
      &update_in(&1.credentials, fn credentials -> Map.delete(credentials, key) end)
    )
  end

  def authorize(
        %{id: operation},
        input,
        %Context{metadata: %{lease_store: store}} = context,
        _connection
      ) do
    Agent.get(store, &authorize_grant(&1, context, operation, input))
  end

  @impl true
  def resolve_lease(
        %Context{connection: connection, metadata: %{lease_store: store}} = context,
        operation,
        input
      ) do
    # Recheck the current grant and read the credential in one store operation.
    Agent.get(store, fn state ->
      with :ok <- authorize_grant(state, context, operation, input),
           {:ok, credential} <- Map.fetch(state.credentials, credential_key(connection)) do
        CredentialLease.from_connection(
          connection,
          %{access_token: credential.access_token, github_client: state.github_client},
          scopes: credential.scopes,
          expires_at: DateTime.add(DateTime.utc_now(), 60),
          metadata: %{credential_version: credential.version}
        )
      else
        :error ->
          {:error, Error.auth("Credential is unavailable", reason: :credential_unavailable)}

        {:error, _reason} = error ->
          error
      end
    end)
  end

  defp authorize_grant(
         state,
         %Context{
           tenant_id: tenant,
           actor: %{id: actor},
           connection: %Connection{tenant_id: tenant} = connection
         },
         "github.pull_request.get",
         %{repo: repo}
       ) do
    case Map.get(state.grants, connection_key(connection)) do
      %{connection: ^connection, actor_id: ^actor, repo: ^repo} -> :ok
      _other -> deny()
    end
  end

  defp authorize_grant(_state, _context, _operation, _input), do: deny()

  defp deny,
    do:
      {:error,
       Error.auth("Connection grant does not allow this request", reason: :grant_required)}

  defp connection_key(connection), do: {connection.tenant_id, connection.id}

  defp credential_key(connection),
    do: {connection.tenant_id, connection.provider, connection.credential_ref}
end
