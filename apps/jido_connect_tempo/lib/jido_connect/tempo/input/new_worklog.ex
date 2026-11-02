defmodule Jido.Connect.Tempo.Input.NewWorklog do
  @moduledoc false

  # The input of one worklog create. The preview checks it at prepare, the
  # handler before it resolves the provider client and the client before its
  # POST, so an injected client never receives an invalid worklog and the
  # rule exists once. Values are kept as given: no trimming, rounding or time
  # zone shift. A nil value counts as absent.
  #
  # parse/1 checks the keys and the form of each value; check_author/3
  # checks that the author is the connection's account.

  alias Jido.Connect.Error
  alias Jido.Connect.Tempo.Input.DateRange

  @required [:author_account_id, :issue_id, :start_date, :time_spent_seconds]
  @optional [:description, :attributes, :start_time, :billable_seconds]

  @type t :: %{
          required(:author_account_id) => String.t(),
          required(:issue_id) => pos_integer(),
          required(:start_date) => String.t(),
          required(:time_spent_seconds) => pos_integer(),
          optional(:description) => String.t(),
          optional(:attributes) => [%{key: String.t(), value: String.t()}],
          optional(:start_time) => String.t(),
          optional(:billable_seconds) => non_neg_integer()
        }

  @spec parse(term()) :: {:ok, t()} | {:error, Error.ValidationError.t()}
  def parse(input) when is_map(input) do
    with :ok <- known_keys(input),
         {:ok, worklog} <- required(input) do
      optional(input, worklog)
    end
  end

  def parse(_input), do: invalid(:input, "must be a map")

  @spec check_author(t(), String.t(), String.t() | nil) ::
          {:ok, t()} | {:error, Error.AuthError.t()}
  def check_author(%{author_account_id: author} = worklog, account_id, connection_id)
      when is_binary(account_id) do
    if author == account_id do
      {:ok, worklog}
    else
      {:error,
       Error.auth("Tempo worklog author must be the connection's account",
         reason: :foreign_worklog_author,
         connection_id: connection_id,
         details: %{field: :author_account_id}
       )}
    end
  end

  defp known_keys(input) do
    case input |> Map.keys() |> Enum.reject(&(&1 in @required or &1 in @optional)) do
      [] -> :ok
      unknown -> invalid(:input, "holds unknown keys", %{unknown_keys: Enum.sort(unknown)})
    end
  end

  defp required(input) do
    Enum.reduce_while(@required, {:ok, %{}}, fn field, {:ok, worklog} ->
      case Map.get(input, field) do
        nil -> {:halt, invalid(field, "is required")}
        value -> field |> check(value) |> put(field, worklog)
      end
    end)
  end

  defp optional(input, worklog) do
    Enum.reduce_while(@optional, {:ok, worklog}, fn field, {:ok, worklog} ->
      case Map.get(input, field) do
        nil -> {:cont, {:ok, worklog}}
        value -> field |> check(value) |> put(field, worklog)
      end
    end)
  end

  defp put({:ok, value}, field, worklog), do: {:cont, {:ok, Map.put(worklog, field, value)}}
  defp put(error, _field, _worklog), do: {:halt, error}

  defp check(:author_account_id, value) when is_binary(value), do: {:ok, value}
  defp check(:issue_id, value) when is_integer(value) and value > 0, do: {:ok, value}

  defp check(:issue_id, _value),
    do: invalid(:issue_id, "must be the numeric Jira issue ID, a positive integer")

  defp check(:time_spent_seconds, value) when is_integer(value) and value > 0, do: {:ok, value}

  defp check(:time_spent_seconds, _value),
    do: invalid(:time_spent_seconds, "must be a whole number of seconds of at least 1")

  defp check(:billable_seconds, value) when is_integer(value) and value >= 0, do: {:ok, value}

  defp check(:billable_seconds, _value),
    do: invalid(:billable_seconds, "must be a whole number of seconds of at least 0")

  defp check(:start_date, value) do
    case DateRange.iso_date(value) do
      {:ok, _date} -> {:ok, value}
      :error -> invalid(:start_date, "must be an ISO date such as 2026-10-29")
    end
  end

  defp check(:start_time, value) do
    with true <- is_binary(value) and Regex.match?(~r/\A\d{2}:\d{2}:\d{2}\z/, value),
         {:ok, _time} <- Time.from_iso8601(value) do
      {:ok, value}
    else
      _invalid -> invalid(:start_time, "must be a time of day as HH:mm:ss, such as 09:00:00")
    end
  end

  defp check(:description, value) when is_binary(value), do: {:ok, value}
  defp check(:attributes, values) when is_list(values), do: attributes(values)
  defp check(field, _value), do: invalid(field, "has the wrong type")

  defp attributes(values) do
    pairs = Enum.map(values, &attribute/1)

    cond do
      Enum.any?(pairs, &(&1 == :error)) ->
        invalid(:attributes, "must be maps with exactly a key and a value, both strings")

      pairs |> Enum.uniq_by(& &1.key) |> length() != length(pairs) ->
        invalid(:attributes, "must have unique keys")

      true ->
        {:ok, pairs}
    end
  end

  # Exactly a key and a value, each named as an atom or a string.
  defp attribute(value) when is_map(value) and map_size(value) == 2 do
    with {:ok, key} <- fetch(value, :key),
         {:ok, attribute_value} <- fetch(value, :value),
         true <- is_binary(key) and key != "" and is_binary(attribute_value) do
      %{key: key, value: attribute_value}
    else
      _invalid -> :error
    end
  end

  defp attribute(_value), do: :error

  defp fetch(map, key) do
    case {Map.fetch(map, key), Map.fetch(map, Atom.to_string(key))} do
      {{:ok, value}, :error} -> {:ok, value}
      {:error, {:ok, value}} -> {:ok, value}
      _missing_or_both -> :error
    end
  end

  defp invalid(field, message, details \\ %{}) do
    {:error,
     Error.validation("Invalid Tempo worklog",
       reason: :invalid_worklog_input,
       subject: field,
       details: Map.merge(%{field: field, message: message}, details)
     )}
  end
end
