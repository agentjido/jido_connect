defmodule Jido.Connect.Things.Reader do
  @moduledoc """
  Reads complete Things Cloud history into storage-free V1 current state.

  Raw events remain private in the returned state. Malformed or unknown data is
  retained and makes the state unsafe for writes.
  """

  alias Jido.Connect.Error
  alias Jido.Connect.Things.{Client, Protocol, State, Todo}
  alias Jido.Connect.Things.Client.{Account, History}

  def list_open_inbox(%Client{} = client, limit) when is_integer(limit) and limit in 1..100 do
    with {:ok, account, history} <- snapshot(client),
         {:ok, state} <- load_state(client, account, history),
         :ok <- require_read_safe_fold(state) do
      todos =
        state
        |> State.active_tasks()
        |> Enum.filter(&Todo.visible_open_inbox?/1)
        |> Enum.sort_by(&{&1.position || 0, String.downcase(&1.title), &1.id})
        |> Enum.take(limit)

      {:ok,
       %{
         view: "inbox",
         count: length(todos),
         todos: Enum.map(todos, &Todo.to_public_map/1),
         freshness: %{source: "provider", provider_head: history.head}
       }}
    end
  end

  def fetch_todo(%Client{} = client, id) when is_binary(id) do
    with {:ok, account, history} <- snapshot(client),
         {:ok, state} <- load_state(client, account, history),
         :ok <- require_read_safe_fold(state) do
      case Enum.find(State.active_tasks(state), &(&1.id == id)) do
        %Todo{} = todo -> {:ok, todo, account, history}
        nil -> protocol_error(:todo_not_found, %{id: id})
      end
    end
  end

  def snapshot(%Client{} = client) do
    with :ok <- Protocol.validate_endpoint(client),
         {:ok, account} <- Client.verify_account(client),
         :ok <- Protocol.validate_account(client, account),
         {:ok, history} <- Client.history(client, account.history_key),
         :ok <- Protocol.validate_history(history) do
      {:ok, account, history}
    end
  end

  def load(%Client{} = client, %Account{} = account, %History{} = history) do
    with {:ok, state} <- load_state(client, account, history),
         :ok <- require_write_safe_fold(state) do
      {:ok, State.active_tasks(state)}
    end
  end

  def load_state(%Client{} = client, %Account{} = account, %History{} = history, opts \\ []) do
    state =
      opts
      |> Keyword.get(:state, State.new())
      |> State.bind_history(Protocol.history_fingerprint(account))

    start_index = Keyword.get(opts, :start_index, state.last_server_index)

    with :ok <- validate_incremental_start(state, start_index, history.head),
         {:ok, state} <-
           fetch_pages(client, account.history_key, start_index, history.head, state, 0),
         {:ok, state} <- State.finish(state, history.head) do
      {:ok, state}
    else
      {:error, %_{} = error} -> {:error, error}
      {:error, reason} -> protocol_error_from_state(reason)
    end
  end

  defp fetch_pages(_client, _history_key, start, head, state, _page_count) when start >= head,
    do: {:ok, state}

  defp fetch_pages(_client, _history_key, _start, _head, _state, page_count)
       when page_count >= 10_000,
       do: protocol_error(:history_page_limit_exceeded)

  defp fetch_pages(client, history_key, start, head, state, page_count) do
    with {:ok, %{"items" => items}} <- Client.history_page(client, history_key, start),
         :ok <- require_nonempty_page(items, start, head),
         {:ok, state} <- State.apply_page(state, items, start) do
      fetch_pages(client, history_key, start + length(items), head, state, page_count + 1)
    end
  end

  defp require_nonempty_page([], start, head) when start < head,
    do: protocol_error(:incomplete_history, %{start_index: start, provider_head: head})

  defp require_nonempty_page(items, _start, _head) when is_list(items), do: :ok
  defp require_nonempty_page(_items, _start, _head), do: protocol_error(:invalid_history_page)

  defp validate_incremental_start(%State{last_server_index: start}, start, head)
       when start <= head,
       do: :ok

  defp validate_incremental_start(_state, start, head),
    do: protocol_error(:invalid_incremental_start, %{start_index: start, provider_head: head})

  defp require_write_safe_fold(%State{write_safe?: true}), do: :ok

  defp require_write_safe_fold(%State{} = state) do
    protocol_error(fold_error_reason(state.issues), %{
      issue_count: length(state.issues),
      issues: Enum.take(state.issues, 10)
    })
  end

  defp require_read_safe_fold(%State{} = state) do
    case task_fold_error_reason(state.issues) do
      nil -> :ok
      reason -> protocol_error(reason, %{issue_count: length(state.issues)})
    end
  end

  defp fold_error_reason(issues) do
    task_fold_error_reason(issues) || :unsafe_materialized_state
  end

  defp task_fold_error_reason(issues) do
    Enum.find_value(issues, fn
      %{reason: :unsupported_event, details: %{entity: entity}}
      when entity in ~w(Task Task2 Task3 Task4 Task6) ->
        :unsupported_task_event

      %{reason: :unsupported_event, details: %{entity: "Task" <> _version}} ->
        :unsupported_task_entity

      _issue ->
        nil
    end)
  end

  defp protocol_error_from_state(%{reason: reason} = details), do: protocol_error(reason, details)

  defp protocol_error_from_state(reason),
    do: protocol_error(:invalid_materialized_state, %{error: reason})

  defp protocol_error(reason, details \\ %{}) do
    {:error,
     Error.provider("Things Cloud history did not match the supported schema",
       provider: :things,
       reason: reason,
       details: details
     )}
  end
end
