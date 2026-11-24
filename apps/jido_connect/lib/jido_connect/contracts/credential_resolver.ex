defmodule Jido.Connect.CredentialResolver do
  @moduledoc """
  Resolves a credential lease from trusted host execution context.

  Implementations must check current grants for the tenant, actor, connection,
  operation, and target before reading credential material. The runtime calls
  the resolver with parsed input and keeps the returned lease inside the call.
  Configure the resolver on an Agent's Connect binding, on
  `Jido.Connect.Context`, or in trusted runtime options.
  """

  alias Jido.Connect.{Callback, Context, CredentialLease, Error}
  alias Jido.Connect.Error.AuthError

  @callback resolve_lease(Context.t(), String.t(), map()) ::
              {:ok, CredentialLease.t()} | {:error, AuthError.t()}

  @doc false
  def resolve(resolver, %Context{} = context, operation_id, input)
      when is_atom(resolver) and not is_nil(resolver) do
    case Callback.call(resolver, :resolve_lease, [context, operation_id, input],
           phase: :credential_resolution
         ) do
      {:ok, {:ok, %CredentialLease{} = lease}} ->
        {:ok, lease}

      {:ok, {:error, %AuthError{reason: reason}}} when is_atom(reason) ->
        {:error, Error.auth("Credential resolution denied", reason: reason)}

      _ ->
        {:error,
         Error.execution("Credential resolver failed",
           phase: :credential_resolution,
           details: %{operation_id: operation_id}
         )}
    end
  end

  def resolve(_, _, _, _),
    do: {:error, Error.config("Expected a credential resolver module", key: :credential_resolver)}
end
