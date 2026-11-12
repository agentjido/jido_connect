defmodule Jido.Connect.Tempo.Worklog do
  @moduledoc """
  Normalized Tempo worklog.

  `normalize/1` reads one worklog of a Tempo REST v4 response through an
  allowlist: it takes the Tempo fields below and drops every other key.

  | Field | Tempo field | When Tempo leaves it out |
  | --- | --- | --- |
  | `tempo_worklog_id` | `tempoWorklogId`, a positive integer | error |
  | `author_account_id` | `author.accountId`, a non-empty string | error |
  | `start_date` | `startDate`, the booking day as an ISO date | error |
  | `time_spent_seconds` | `timeSpentSeconds`, a non-negative integer | error |
  | `issue_id` | `issue.id`, the numeric Jira issue ID, a positive integer | error |
  | `description` | `description`, a string | `nil` |
  | `work_attributes` | `attributes.values`, as `%{key: key, value: value}` maps | `[]` |
  | `start_time` | `startTime`, an ISO time | `nil` |
  | `start_date_time_utc` | `startDateTimeUtc`, an ISO date-time | `nil` |
  | `billable_seconds` | `billableSeconds`, a non-negative integer | `nil` |
  | `created_at` | `createdAt`, an ISO date-time | `nil` |
  | `updated_at` | `updatedAt`, an ISO date-time | `nil` |
  | `self` | `self`, Tempo's link to the worklog | `nil` |

  Values are kept as Tempo sends them: seconds stay exact integers and an
  empty description stays `""`, apart from an absent one. `start_date` is the
  booking day in the worker's time zone; it can differ from the date of
  `start_date_time_utc`. A work attribute value is a string or `nil`, as
  Tempo's OpenAPI declares it.

  A required field that is missing or malformed, and an optional field of
  the wrong type, make `normalize/1` return `{:error, field}` with the Tempo
  field path, such as `"author.accountId"`. No value is guessed and no
  record is skipped; `Jido.Connect.Tempo.Client.list_own_worklogs/2` fails
  the whole read instead.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              tempo_worklog_id: Zoi.integer() |> Zoi.positive(),
              author_account_id: Zoi.string() |> Zoi.min(1),
              start_date: Zoi.ISO.date(),
              time_spent_seconds: Zoi.integer() |> Zoi.non_negative(),
              issue_id: Zoi.integer() |> Zoi.positive(),
              description: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              work_attributes: Zoi.list(Zoi.map()),
              start_time: Zoi.ISO.time() |> Zoi.nullish() |> Zoi.optional(),
              start_date_time_utc: Zoi.ISO.datetime() |> Zoi.nullish() |> Zoi.optional(),
              billable_seconds:
                Zoi.integer() |> Zoi.non_negative() |> Zoi.nullish() |> Zoi.optional(),
              created_at: Zoi.ISO.datetime() |> Zoi.nullish() |> Zoi.optional(),
              updated_at: Zoi.ISO.datetime() |> Zoi.nullish() |> Zoi.optional(),
              self: Zoi.string() |> Zoi.nullish() |> Zoi.optional()
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  # Struct field => path of the Tempo field.
  @fields [
    tempo_worklog_id: ["tempoWorklogId"],
    author_account_id: ["author", "accountId"],
    start_date: ["startDate"],
    time_spent_seconds: ["timeSpentSeconds"],
    issue_id: ["issue", "id"],
    description: ["description"],
    work_attributes: ["attributes", "values"],
    start_time: ["startTime"],
    start_date_time_utc: ["startDateTimeUtc"],
    billable_seconds: ["billableSeconds"],
    created_at: ["createdAt"],
    updated_at: ["updatedAt"],
    self: ["self"]
  ]

  @optional [
    :start_time,
    :start_date_time_utc,
    :billable_seconds,
    :created_at,
    :updated_at,
    :self
  ]

  @doc """
  Normalizes one Tempo worklog.

  Returns `{:error, field}` with the Tempo field path of a missing or
  malformed field, or `{:error, "worklog"}` when the value is not a map.
  """
  @spec normalize(term()) :: {:ok, t()} | {:error, String.t()}
  def normalize(payload) when is_map(payload) do
    with {:ok, attrs} <- extract(payload),
         {:ok, attrs} <- work_attributes(attrs) do
      case Zoi.parse(@schema, attrs) do
        {:ok, worklog} -> {:ok, worklog}
        {:error, [%Zoi.Error{path: [field | _rest]} | _errors]} -> {:error, tempo_field(field)}
      end
    end
  end

  def normalize(_payload), do: {:error, "worklog"}

  @doc """
  Returns the worklog as a plain map for action output.

  The optional `start_time`, `start_date_time_utc`, `billable_seconds`,
  `created_at`, `updated_at` and `self` are left out when Tempo did not send
  them. `description` is always present, `nil` when Tempo sent none.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = worklog) do
    worklog
    |> Map.from_struct()
    |> Map.reject(fn {key, value} -> key in @optional and is_nil(value) end)
  end

  defp extract(payload) do
    Enum.reduce_while(@fields, {:ok, %{}}, fn {field, path}, {:ok, attrs} ->
      case fetch(payload, path) do
        {:ok, value} -> {:cont, {:ok, Map.put(attrs, field, value)}}
        :error -> {:halt, {:error, Enum.join(path, ".")}}
      end
    end)
  end

  # A missing key or a JSON null is nil; a parent that is present but not an
  # object is malformed.
  defp fetch(value, []), do: {:ok, value}
  defp fetch(map, [key | rest]) when is_map(map), do: fetch(Map.get(map, key), rest)
  defp fetch(nil, _path), do: {:ok, nil}
  defp fetch(_value, _path), do: :error

  defp work_attributes(%{work_attributes: nil} = attrs),
    do: {:ok, %{attrs | work_attributes: []}}

  defp work_attributes(%{work_attributes: values} = attrs) when is_list(values) do
    if Enum.all?(values, &work_attribute?/1) do
      pairs = Enum.map(values, &%{key: &1["key"], value: &1["value"]})
      {:ok, %{attrs | work_attributes: pairs}}
    else
      {:error, "attributes.values"}
    end
  end

  defp work_attributes(_attrs), do: {:error, "attributes.values"}

  defp work_attribute?(%{"key" => key} = value) when is_binary(key) and key != "",
    do: is_nil(value["value"]) or is_binary(value["value"])

  defp work_attribute?(_value), do: false

  defp tempo_field(field), do: @fields |> Keyword.fetch!(field) |> Enum.join(".")
end
