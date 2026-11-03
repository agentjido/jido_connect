defmodule Jido.Connect.Tempo.Account do
  @moduledoc """
  Tempo account that a Jira project offers as a booking target, with the
  evidence of the links that make it a candidate.

  `normalize/2` reads the answer of `GET /4/accounts/{id}` through an
  allowlist and adds the link evidence of the project read:

  | Field | Tempo field | When Tempo leaves it out |
  | --- | --- | --- |
  | `id` | `id`, a positive integer | error |
  | `key` | `key`, a non-empty string | error |
  | `name` | `name`, a string | error |
  | `status` | `status`, a non-empty string | error |
  | `global` | `global`, a boolean | error |
  | `self` | `self`, Tempo's link to the account | `nil` |
  | `links` | the project's links to this account, in Tempo's order | never empty |

  Each link is a map with `id`, the link ID, `default`, `scope_type` and
  `scope_id`. On the test site Tempo reports a global account as a link
  with ID 0 on the requested project. An account with two links of the
  project keeps both entries.

  `status` is kept as Tempo sends it. Tempo documents `OPEN`, `CLOSED` and
  `ARCHIVED`; any other value stays the raw string. A closed or archived
  account stays a candidate with its status; whether it may be booked is
  the host's decision.

  The dropped fields include the lead, the contact, the customer, the
  category, the monthly budget and the `links` reference of the account.
  The `key` is the value of an `ACCOUNT` work attribute.
  """

  @link Zoi.map(%{
          id: Zoi.integer() |> Zoi.non_negative(),
          default: Zoi.boolean(),
          scope_type: Zoi.string() |> Zoi.min(1),
          scope_id: Zoi.integer()
        })

  @schema Zoi.struct(
            __MODULE__,
            %{
              id: Zoi.integer() |> Zoi.positive(),
              key: Zoi.string() |> Zoi.min(1),
              name: Zoi.string(),
              status: Zoi.string() |> Zoi.min(1),
              global: Zoi.boolean(),
              self: Zoi.string() |> Zoi.nullish() |> Zoi.optional(),
              links: Zoi.list(@link) |> Zoi.min(1)
            },
            coerce: true
          )

  @type link :: %{
          id: non_neg_integer(),
          default: boolean(),
          scope_type: String.t(),
          scope_id: integer()
        }
  @type t :: unquote(Zoi.type_spec(@schema))
  @enforce_keys Zoi.Struct.enforce_keys(@schema)
  defstruct Zoi.Struct.struct_fields(@schema)

  @fields [:id, :key, :name, :status, :global, :self]

  @doc """
  Normalizes the details of one Tempo account with its link evidence.

  Returns `{:error, field}` with the Tempo field of a missing or malformed
  value, or `{:error, "account"}` when the details are not a map.
  """
  @spec normalize(term(), [link()]) :: {:ok, t()} | {:error, String.t()}
  def normalize(payload, links) when is_map(payload) and is_list(links) do
    attrs =
      @fields
      |> Map.new(&{&1, Map.get(payload, Atom.to_string(&1))})
      |> Map.put(:links, links)

    case Zoi.parse(@schema, attrs) do
      {:ok, account} -> {:ok, account}
      {:error, [%Zoi.Error{path: [field | _rest]} | _errors]} -> {:error, to_string(field)}
    end
  end

  def normalize(_payload, _links), do: {:error, "account"}

  @doc "Returns the account as a plain map for action output."
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = account), do: Map.from_struct(account)
end
