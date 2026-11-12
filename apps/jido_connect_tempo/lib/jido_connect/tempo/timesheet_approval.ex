defmodule Jido.Connect.Tempo.TimesheetApproval do
  @moduledoc """
  Normalized Tempo timesheet approval of one user for one period.

  `normalize/1` reads the answer of
  `GET /4/timesheet-approvals/user/{accountId}` through an allowlist: it
  takes the Tempo fields below and drops every other key.

  | Field | Tempo field | When Tempo leaves it out |
  | --- | --- | --- |
  | `period_from` | `period.from`, an ISO date | error |
  | `period_to` | `period.to`, an ISO date | error |
  | `user_account_id` | `user.accountId`, a non-empty string | error |
  | `status` | `status.key`, a non-empty string | `nil` |
  | `updated_at` | `status.updatedAt`, a non-empty string | `nil` |

  `status` is kept as Tempo sends it. Tempo documents `OPEN`, `IN_REVIEW`
  and `APPROVED`; any other key stays the raw string and never becomes an
  atom. A missing status stays `nil` and is never read as `OPEN`.
  `updated_at` is kept as sent as well: on the test site a UTC timestamp
  such as `2026-10-30T19:19:42Z`, while Tempo's OpenAPI documents a date. An
  `OPEN` status carries neither `updatedAt` nor an actor.

  The dropped fields include the status comment and actor, the reviewer,
  the `actions` links such as `submit` and `recall`, the worklog link,
  `self` and the required and spent seconds.

  A required field that is missing or malformed, and an optional field of
  the wrong type, make `normalize/1` return `{:error, field}` with the Tempo
  field path, such as `"user.accountId"`.
  """

  @schema Zoi.struct(
            __MODULE__,
            %{
              period_from: Zoi.ISO.date(),
              period_to: Zoi.ISO.date(),
              user_account_id: Zoi.string() |> Zoi.min(1),
              status: Zoi.string() |> Zoi.min(1) |> Zoi.nullish() |> Zoi.optional(),
              updated_at: Zoi.string() |> Zoi.min(1) |> Zoi.nullish() |> Zoi.optional()
            },
            coerce: true
          )

  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  # Struct field => path of the Tempo field.
  @fields [
    period_from: ["period", "from"],
    period_to: ["period", "to"],
    user_account_id: ["user", "accountId"],
    status: ["status", "key"],
    updated_at: ["status", "updatedAt"]
  ]

  @doc """
  Normalizes one Tempo timesheet approval.

  Returns `{:error, field}` with the Tempo field path of a missing or
  malformed field, or `{:error, "approval"}` when the value is not a map.
  """
  @spec normalize(term()) :: {:ok, t()} | {:error, String.t()}
  def normalize(payload) when is_map(payload) do
    with {:ok, attrs} <- extract(payload) do
      case Zoi.parse(@schema, attrs) do
        {:ok, approval} -> {:ok, approval}
        {:error, [%Zoi.Error{path: [field | _rest]} | _errors]} -> {:error, tempo_field(field)}
      end
    end
  end

  def normalize(_payload), do: {:error, "approval"}

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

  defp tempo_field(field), do: @fields |> Keyword.fetch!(field) |> Enum.join(".")
end
