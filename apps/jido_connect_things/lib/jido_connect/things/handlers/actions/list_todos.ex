defmodule Jido.Connect.Things.Handlers.Actions.ListTodos do
  @moduledoc false

  alias Jido.Connect.Error

  alias Jido.Connect.Things.{
    Client,
    ReadAdapter,
    Reader,
    Runtime
  }

  def run(%{view: "inbox", limit: limit}, %{context: context, credential_lease: lease}) do
    runtime = Runtime.runtime_context(context)

    case Map.get(runtime, :read_adapter) do
      nil ->
        with {:ok, client} <- Client.from_runtime(context, lease, runtime) do
          Reader.list_open_inbox(client, limit)
        end

      adapter ->
        with {:ok, result} <- ReadAdapter.list(adapter, context.connection.id, limit),
             {:ok, output} <- normalize_adapter_result(result, limit) do
          {:ok, output}
        end
    end
  end

  def run(_input, _runtime) do
    {:error,
     Error.validation("Things list input is invalid",
       reason: :invalid_list_input
     )}
  end

  defp normalize_adapter_result(result, limit) do
    todos = Map.get(result, :todos) || Map.get(result, "todos")
    freshness = Map.get(result, :freshness) || Map.get(result, "freshness")

    if is_list(todos) and length(todos) <= limit do
      {:ok,
       %{
         view: "inbox",
         count: length(todos),
         todos: Enum.map(todos, &Jido.Connect.Sanitizer.sanitize(&1, :transport)),
         freshness: Jido.Connect.Sanitizer.sanitize(freshness, :transport)
       }
       |> Enum.reject(fn {_key, value} -> is_nil(value) end)
       |> Map.new()}
    else
      {:error,
       Error.provider("Things host read adapter returned invalid list data",
         provider: :things,
         reason: :invalid_read_adapter_result
       )}
    end
  end
end
