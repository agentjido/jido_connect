defmodule Jido.Connect.Things.Reader do
  @moduledoc """
  Rebuilds the small to-do read model from Things Cloud history.

  This reader recognizes the observed schema-301 task envelope only. It fails
  closed on unknown task enums or unsafe object identifiers.
  """

  alias Jido.Connect.Error
  alias Jido.Connect.Things.{Client, Identifier, Protocol, Todo}
  alias Jido.Connect.Things.Client.{Account, History}

  @task_entities ~w(Task Task2 Task3 Task4 Task6)

  def list_open_inbox(%Client{} = client, limit) when is_integer(limit) and limit in 1..100 do
    with {:ok, account, history} <- snapshot(client),
         {:ok, todos} <- load(client, account, history) do
      todos =
        todos
        |> Enum.filter(&Todo.eligible_inbox?/1)
        |> Enum.sort_by(&{&1.title, &1.id})
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
         {:ok, todos} <- load(client, account, history) do
      case Enum.find(todos, &(&1.id == id)) do
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
    with {:ok, state} <- fetch_pages(client, account.history_key, 0, history.head, %{}, 0) do
      state
      |> Map.values()
      |> Enum.reject(&Map.get(&1, :deleted, false))
      |> Enum.reduce_while({:ok, []}, fn attrs, {:ok, todos} ->
        case Todo.new(attrs) do
          {:ok, todo} -> {:cont, {:ok, [todo | todos]}}
          {:error, _reason} -> {:halt, protocol_error(:invalid_todo_state)}
        end
      end)
      |> case do
        {:ok, todos} -> {:ok, Enum.reverse(todos)}
        {:error, _error} = error -> error
      end
    end
  end

  defp fetch_pages(_client, _history_key, start, head, state, _page_count) when start >= head,
    do: {:ok, state}

  defp fetch_pages(_client, _history_key, _start, _head, _state, page_count)
       when page_count >= 10_000,
       do: protocol_error(:history_page_limit_exceeded)

  defp fetch_pages(client, history_key, start, head, state, page_count) do
    with {:ok, %{"items" => items}} <- Client.history_page(client, history_key, start),
         {:ok, state} <- apply_server_items(items, state) do
      case length(items) do
        0 ->
          protocol_error(:incomplete_history, %{
            start_index: start,
            provider_head: head
          })

        count ->
          fetch_pages(client, history_key, start + count, head, state, page_count + 1)
      end
    end
  end

  defp apply_server_items(items, state) do
    Enum.reduce_while(items, {:ok, state}, fn
      item, {:ok, state} when is_map(item) ->
        case apply_server_item(item, state) do
          {:ok, state} -> {:cont, {:ok, state}}
          {:error, _error} = error -> {:halt, error}
        end

      _item, _acc ->
        {:halt, protocol_error(:invalid_history_item)}
    end)
  end

  defp apply_server_item(item, state) do
    Enum.reduce_while(item, {:ok, state}, fn {id, event}, {:ok, state} ->
      case apply_event(id, event, state) do
        {:ok, state} -> {:cont, {:ok, state}}
        {:error, _error} = error -> {:halt, error}
      end
    end)
  end

  defp apply_event(id, %{"e" => entity, "t" => 2}, state) when entity in @task_entities do
    with :ok <- validate_identifier(id) do
      {:ok, Map.update(state, id, %{id: id, deleted: true}, &Map.put(&1, :deleted, true))}
    end
  end

  defp apply_event(_id, %{"e" => "Tombstone2", "p" => %{"dloid" => target}}, state)
       when is_binary(target) do
    with :ok <- validate_identifier(target) do
      {:ok, Map.update(state, target, %{id: target, deleted: true}, &Map.put(&1, :deleted, true))}
    end
  end

  defp apply_event(id, %{"e" => entity, "t" => action, "p" => payload}, state)
       when entity in @task_entities and action in [0, 1] and is_map(payload) do
    with :ok <- validate_identifier(id),
         {:ok, attrs} <- decode_payload(payload) do
      defaults = %{
        id: id,
        title: "",
        notes: "",
        status: :open,
        schedule: :anytime,
        type: :task,
        in_trash: false,
        deleted: false
      }

      current = Map.get(state, id, defaults)
      attrs = Map.put_new(attrs, :modified_at, Map.get(attrs, :created_at))
      attrs = if Map.get(attrs, :modified_at), do: attrs, else: Map.delete(attrs, :modified_at)
      {:ok, Map.put(state, id, current |> Map.merge(attrs) |> Map.delete(:created_at))}
    end
  end

  defp apply_event(id, %{"e" => entity} = event, _state) when entity in @task_entities do
    with :ok <- validate_identifier(id) do
      protocol_error(:unsupported_task_event, %{entity: entity, action: Map.get(event, "t")})
    end
  end

  defp apply_event(id, %{"e" => entity}, state) when is_binary(entity) do
    if String.starts_with?(entity, "Task") do
      with :ok <- validate_identifier(id) do
        protocol_error(:unsupported_task_entity, %{entity: entity})
      end
    else
      {:ok, state}
    end
  end

  defp apply_event(_id, _event, state), do: {:ok, state}

  defp decode_payload(payload) do
    with {:ok, status} <- enum(payload, "ss", %{0 => :open, 2 => :canceled, 3 => :completed}),
         {:ok, schedule} <- enum(payload, "st", %{0 => :inbox, 1 => :anytime, 2 => :someday}),
         {:ok, type} <- enum(payload, "tp", %{0 => :task, 1 => :project, 2 => :heading}),
         {:ok, created_at} <- optional_timestamp(payload, "cd"),
         {:ok, modified_at} <- optional_timestamp(payload, "md") do
      {:ok,
       %{}
       |> maybe_put(:title, value(payload, "tt"))
       |> maybe_put(:notes, note(payload))
       |> maybe_put(:status, status)
       |> maybe_put(:schedule, schedule)
       |> maybe_put(:type, type)
       |> maybe_put(:in_trash, value(payload, "tr"))
       |> maybe_put(:created_at, created_at)
       |> maybe_put(:modified_at, modified_at)}
    end
  end

  defp enum(payload, key, values) do
    case Map.fetch(payload, key) do
      :error -> {:ok, nil}
      {:ok, nil} -> {:ok, nil}
      {:ok, value} -> Map.fetch(values, value) |> normalize_enum(key, value)
    end
  end

  defp normalize_enum({:ok, value}, _key, _raw), do: {:ok, value}

  defp normalize_enum(:error, key, raw),
    do: protocol_error(:unsupported_wire_value, %{key: key, value: raw})

  defp optional_timestamp(payload, key) do
    case Map.fetch(payload, key) do
      :error -> {:ok, nil}
      {:ok, nil} -> {:ok, nil}
      {:ok, value} -> timestamp(value)
    end
  end

  defp timestamp(value) when is_integer(value), do: normalize_timestamp(DateTime.from_unix(value))

  defp timestamp(value) when is_float(value) do
    value
    |> Kernel.*(1_000_000)
    |> round()
    |> DateTime.from_unix(:microsecond)
    |> normalize_timestamp()
  end

  defp timestamp(_value), do: protocol_error(:invalid_timestamp)

  defp normalize_timestamp({:ok, %DateTime{} = datetime}), do: {:ok, datetime}
  defp normalize_timestamp(_error), do: protocol_error(:invalid_timestamp)

  defp note(%{"nt" => note}) when is_binary(note), do: note
  defp note(%{"nt" => %{"v" => note}}) when is_binary(note), do: note
  defp note(_payload), do: nil

  defp value(payload, key), do: Map.get(payload, key)

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp validate_identifier(id) do
    case Identifier.validate(id) do
      :ok -> :ok
      {:error, reason} -> protocol_error(:unsafe_identifier, %{reason: reason})
    end
  end

  defp protocol_error(reason, details \\ %{}) do
    {:error,
     Error.provider("Things Cloud history did not match the supported schema",
       provider: :things,
       reason: reason,
       details: details
     )}
  end
end
