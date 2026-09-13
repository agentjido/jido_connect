defmodule Jido.Connect.ScopeRequirements do
  @moduledoc """
  Resolves static or provider-specific scope requirements for operations.
  """

  alias Jido.Connect.{Callback, Connection, Error}

  @type operation :: map()

  @spec required_scopes(operation(), map(), Connection.t() | nil) ::
          {:ok, [String.t()]} | {:error, Error.error()}
  def required_scopes(operation, input \\ %{}, connection \\ nil) when is_map(operation) do
    case Map.get(operation, :scope_resolver) do
      nil ->
        {:ok, static_scopes(operation)}

      resolver when is_atom(resolver) ->
        call_resolver(resolver, operation, input, connection)
    end
  end

  defp call_resolver(resolver, operation, input, connection) do
    case Code.ensure_loaded(resolver) do
      {:module, ^resolver} ->
        call_loaded_resolver(resolver, operation, input, connection)

      {:error, reason} ->
        {:error,
         Error.config("Scope resolver module could not be loaded",
           key: :scope_resolver,
           details: %{module: resolver, reason: reason}
         )}
    end
  end

  defp call_loaded_resolver(resolver, operation, input, connection) do
    cond do
      function_exported?(resolver, :required_scopes, 3) ->
        with {:ok, result} <-
               Callback.call(resolver, :required_scopes, [operation, input, connection],
                 phase: :scope_resolver,
                 details: %{module: resolver, operation_id: operation_id(operation)}
               ) do
          normalize_result(result, resolver)
        end

      function_exported?(resolver, :required_scopes, 2) ->
        with {:ok, result} <-
               Callback.call(resolver, :required_scopes, [operation, input],
                 phase: :scope_resolver,
                 details: %{module: resolver, operation_id: operation_id(operation)}
               ) do
          normalize_result(result, resolver)
        end

      true ->
        {:error,
         Error.config("Scope resolver does not export required_scopes/2 or required_scopes/3",
           key: :scope_resolver,
           details: %{module: resolver}
         )}
    end
  end

  defp normalize_result({:ok, scopes}, _resolver) when is_list(scopes),
    do: {:ok, normalize_scopes(scopes)}

  defp normalize_result({:error, %_{} = error}, _resolver), do: {:error, error}

  defp normalize_result(scopes, _resolver) when is_list(scopes),
    do: {:ok, normalize_scopes(scopes)}

  defp normalize_result(value, resolver) do
    {:error,
     Error.config("Scope resolver returned an invalid value",
       key: :scope_resolver,
       details: %{module: resolver, value: value}
     )}
  end

  defp static_scopes(operation), do: operation |> Map.get(:scopes, []) |> normalize_scopes()

  defp normalize_scopes(scopes) do
    scopes
    |> List.wrap()
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&to_string/1)
    |> Enum.uniq()
  end

  defp operation_id(%{action_id: action_id}), do: action_id
  defp operation_id(%{trigger_id: trigger_id}), do: trigger_id
  defp operation_id(%{id: id}), do: id
  defp operation_id(_operation), do: nil
end
