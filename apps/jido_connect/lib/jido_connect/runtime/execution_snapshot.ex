defmodule Jido.Connect.ExecutionSnapshot do
  @moduledoc false

  alias Jido.Connect.{ActionSpec, Callback, Connection, CredentialLease, Error, Sanitizer}

  @spec hash(term()) :: String.t()
  def hash(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @spec action_hash(ActionSpec.t()) :: String.t()
  def action_hash(%ActionSpec{} = action) do
    action
    |> Map.from_struct()
    |> Map.take([
      :id,
      :name,
      :handler,
      :preview,
      :input,
      :output,
      :scopes,
      :scope_resolver,
      :mutation?,
      :provider_idempotency?,
      :risk,
      :confirmation,
      :metadata
    ])
    |> hash()
  end

  @spec connection_hash(Connection.t()) :: String.t()
  def connection_hash(%Connection{} = connection) do
    connection
    |> Map.from_struct()
    |> hash()
  end

  @spec lease_hash(CredentialLease.t()) :: String.t()
  def lease_hash(%CredentialLease{} = lease) do
    lease
    |> CredentialLease.to_public_map()
    |> hash()
  end

  @spec preview(ActionSpec.t(), map(), Connection.t()) ::
          {:ok, map()} | {:error, Error.error()}
  def preview(%ActionSpec{} = action, input, %Connection{} = connection) do
    base = %{
      action_id: action.id,
      connection: %{
        id: connection.id,
        provider: connection.provider,
        profile: connection.profile,
        subject: Sanitizer.sanitize(connection.subject, :transport)
      },
      input_fields: input |> Map.keys() |> Enum.map(&field_name/1) |> Enum.sort()
    }

    case action.preview do
      nil ->
        {:ok, base}

      module ->
        with {:ok, result} <-
               Callback.call(module, :preview, [input, base],
                 phase: :preview,
                 details: %{operation_id: action.id}
               ),
             {:ok, provider_preview} <- normalize_preview(result, action.id) do
          provider_preview =
            provider_preview
            |> Sanitizer.sanitize(:transport)
            |> Map.new()

          {:ok, Map.merge(provider_preview, base)}
        end
    end
  end

  defp normalize_preview({:ok, preview}, action_id), do: normalize_preview(preview, action_id)
  defp normalize_preview(preview, _action_id) when is_map(preview), do: {:ok, preview}

  defp normalize_preview({:error, %_module{} = error}, action_id) do
    if Error.error?(error),
      do: {:error, error},
      else: {:error, preview_error(error, action_id)}
  end

  defp normalize_preview({:error, reason}, action_id),
    do: {:error, preview_error(reason, action_id)}

  defp normalize_preview(result, action_id),
    do: {:error, preview_error({:invalid_result, result}, action_id)}

  defp preview_error(reason, action_id) do
    Error.execution("Provider preview failed",
      phase: :preview,
      details: %{
        operation_id: action_id,
        error: Sanitizer.sanitize(reason, :transport)
      }
    )
  end

  defp field_name(field) when is_atom(field), do: Atom.to_string(field)
  defp field_name(field) when is_binary(field), do: field
  defp field_name(_field), do: "unknown"
end
