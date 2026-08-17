defmodule Jido.Connect.ExecutionSnapshot do
  @moduledoc false

  alias Jido.Connect.{ActionSpec, Connection, CredentialLease}

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

  @spec preview(ActionSpec.t(), map(), Connection.t()) :: map()
  def preview(%ActionSpec{} = action, input, %Connection{} = connection) do
    %{
      action_id: action.id,
      connection: %{
        id: connection.id,
        provider: connection.provider,
        profile: connection.profile,
        subject: Jido.Connect.Sanitizer.sanitize(connection.subject, :transport)
      },
      input_fields: input |> Map.keys() |> Enum.map(&field_name/1) |> Enum.sort()
    }
  end

  defp field_name(field) when is_atom(field), do: Atom.to_string(field)
  defp field_name(field) when is_binary(field), do: field
  defp field_name(_field), do: "unknown"
end
