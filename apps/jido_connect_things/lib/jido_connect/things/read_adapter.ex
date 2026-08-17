defmodule Jido.Connect.Things.ReadAdapter do
  @moduledoc """
  Optional boundary for a host-owned Things projection.

  Adapter reads are suitable for list output and prepare-time eligibility. The
  guarded writer always uses a fresh provider read again immediately before a
  commit.
  """

  alias Jido.Connect.Error

  @callback list_open_inbox(String.t(), pos_integer()) :: {:ok, map()} | {:error, term()}
  @callback get_todo(String.t(), String.t(), non_neg_integer()) ::
              {:ok, map()} | {:error, term()}

  def list(adapter, connection_id, limit) when is_function(adapter, 2) do
    normalize(adapter.(connection_id, limit), :list)
  end

  def list(adapter, connection_id, limit) when is_atom(adapter) do
    normalize(adapter.list_open_inbox(connection_id, limit), :list)
  rescue
    exception -> adapter_error(:list, exception)
  end

  def get(adapter, connection_id, id, provider_head) when is_function(adapter, 3) do
    normalize(adapter.(connection_id, id, provider_head), :get)
  end

  def get(adapter, connection_id, id, provider_head) when is_atom(adapter) do
    normalize(adapter.get_todo(connection_id, id, provider_head), :get)
  rescue
    exception -> adapter_error(:get, exception)
  end

  defp normalize({:ok, result}, _operation) when is_map(result), do: {:ok, result}
  defp normalize({:error, %_{} = error}, _operation), do: {:error, error}
  defp normalize({:error, reason}, operation), do: adapter_error(operation, reason)
  defp normalize(_result, operation), do: adapter_error(operation, :invalid_response)

  defp adapter_error(operation, reason) do
    {:error,
     Error.provider("Things host read adapter failed",
       provider: :things,
       reason: :read_adapter_failed,
       details: %{
         operation: operation,
         error: Jido.Connect.Sanitizer.provider_body_summary(reason, :transport)
       }
     )}
  end
end
