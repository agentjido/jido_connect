defmodule Jido.Connect.Tempo.ScopeResolver do
  @moduledoc """
  Local labels of the Tempo provider and the grants that satisfy them.

  Tempo actions require five local labels: `tempo.worklogs.read`,
  `tempo.worklogs.write`, `tempo.accounts.read`, `tempo.periods.read` and
  `tempo.approvals.read`. The runtime checks `required -- connection.scopes`,
  so a label counts only when the host has recorded it in
  `connection.scopes`:

  - API token: Tempo does not report a token's rights, so the host records
    the labels the user granted when creating the token.
  - OAuth: the host records `granted_labels/1` of the token response's
    `scope`, or keeps the labels recorded before when that `scope` is `nil`.

  `granted_labels/1` maps two forms of Tempo grants. Five area grants seen
  on the test site map one to one: `worklogs:view` to `tempo.worklogs.read`,
  `worklogs:manage` to `tempo.worklogs.write`, and `accounts:view`,
  `periods:view` and `approvals:view` to the read labels of their areas. The
  coarse grants of Tempo's OpenAPI example map by kind: `read` to the four
  read labels and `write` to `tempo.worklogs.write`. A manage or `write`
  grant implies no read label. Other grants, such as `accounts:manage`,
  `approvals:manage` or `teams:view`, map to no label.

  `required_scopes/3` resolves an operation through `operations/0`, which
  each Tempo action extends with its labels. An operation without an entry
  fails closed with a `Jido.Connect.Error.ConfigError`.
  """

  alias Jido.Connect.{Authorization, Error, Scope}

  # Label => the Tempo grants that satisfy it, in declaration order.
  @grants [
    {"tempo.worklogs.read", ["worklogs:view", "read"]},
    {"tempo.worklogs.write", ["worklogs:manage", "write"]},
    {"tempo.accounts.read", ["accounts:view", "read"]},
    {"tempo.periods.read", ["periods:view", "read"]},
    {"tempo.approvals.read", ["approvals:view", "read"]}
  ]

  @labels Enum.map(@grants, fn {label, _grants} -> label end)

  # Operation ID => labels. Each Tempo action adds its entry here.
  @operations %{
    "tempo.worklogs.list_own" => ["tempo.worklogs.read"],
    "tempo.worklog.create" => ["tempo.worklogs.write"],
    "tempo.period.bookability.get" => ["tempo.periods.read", "tempo.approvals.read"],
    "tempo.work_attribute.list" => ["tempo.worklogs.read"],
    "tempo.account.list_for_project" => ["tempo.accounts.read"]
  }

  @doc "Returns the five local labels in declaration order."
  @spec labels() :: [String.t()]
  def labels, do: @labels

  @doc "Returns the labels each operation requires."
  @spec operations() :: %{String.t() => [String.t()]}
  def operations, do: @operations

  @doc """
  Returns the labels that a recorded Tempo grant satisfies.

  `scope` is the `scope` of an OAuth token response, as a space-separated
  string or a list.
  """
  @spec granted_labels(String.t() | [String.t()] | nil) :: [String.t()]
  def granted_labels(scope) do
    granted = scope |> Scope.parse() |> MapSet.new()
    for {label, grants} <- @grants, Enum.any?(grants, &MapSet.member?(granted, &1)), do: label
  end

  @doc "Returns the labels an operation requires, or a configuration error."
  @spec required_scopes(map(), map(), term()) :: [String.t()] | {:error, Error.ConfigError.t()}
  def required_scopes(operation, _input, _connection) do
    operation_id = Authorization.operation_id(operation)

    Map.get_lazy(@operations, operation_id, fn ->
      {:error,
       Error.config("Tempo operation has no scope mapping",
         key: :scope_resolver,
         details: %{operation_id: operation_id}
       )}
    end)
  end
end
