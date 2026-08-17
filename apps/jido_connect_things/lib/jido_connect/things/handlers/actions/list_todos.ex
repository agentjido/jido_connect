defmodule Jido.Connect.Things.Handlers.Actions.ListTodos do
  @moduledoc false

  alias Jido.Connect.Error

  alias Jido.Connect.Things.{
    Client,
    Query,
    ReadAdapter,
    Reader,
    Runtime
  }

  def run(input, %{context: context, credential_lease: lease}) when is_map(input) do
    runtime = Runtime.runtime_context(context)

    case {Map.get(runtime, :read_adapter), adapter_compatible?(input)} do
      {adapter, true} when not is_nil(adapter) ->
        with {:ok, result} <- ReadAdapter.list(adapter, context.connection.id, input.limit),
             {:ok, output} <- normalize_adapter_result(result, input.limit) do
          {:ok, output}
        end

      _provider_read ->
        with {:ok, client} <- Client.from_runtime(context, lease, runtime),
             {:ok, account, history} <- Reader.snapshot(client),
             {:ok, state} <- Reader.load_state(client, account, history) do
          Query.list(state, input, today: Map.get(runtime, :today, Date.utc_today()))
        end
    end
  end

  def run(_input, _runtime) do
    {:error,
     Error.validation("Things list input is invalid",
       reason: :invalid_list_input
     )}
  end

  defp adapter_compatible?(input) do
    input.view == "inbox" and input.status == "all" and input.tag_ids == [] and
      Map.drop(input, [:view, :status, :tag_ids, :limit]) == %{}
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
