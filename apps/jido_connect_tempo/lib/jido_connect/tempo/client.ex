defmodule Jido.Connect.Tempo.Client do
  @moduledoc """
  Tempo REST v4 client boundary of the Tempo actions.

  Each call receives a `Jido.Connect.Tempo.Client.Request`, which binds the
  selected connection, its account ID, its origin and the leased token.
  Handlers call the client returned by `resolve/1`, so a host or a test can
  inject its own module as `provider_client`.
  """

  alias Jido.Connect.Tempo.Client.{
    Accounts,
    Periods,
    Request,
    TimesheetApprovals,
    WorkAttributes,
    WorklogCreate,
    Worklogs
  }

  @doc "Builds a request from the provider handler runtime."
  defdelegate request_context(runtime), to: Request, as: :from_runtime

  @doc "Returns the injected provider client or the built-in client."
  @spec resolve(map()) :: module()
  def resolve(%{provider_client: client}) when is_atom(client) and not is_nil(client), do: client
  def resolve(_runtime), do: __MODULE__

  @doc """
  Reads every worklog of the request's account with a booking day from
  `:from` to `:to`, both inclusive. See
  `Jido.Connect.Tempo.Client.Worklogs.list_own/2`.
  """
  defdelegate list_own_worklogs(request, opts), to: Worklogs, as: :list_own

  @doc """
  Creates one worklog of the request's account. See
  `Jido.Connect.Tempo.Client.WorklogCreate.create/2`.
  """
  defdelegate create_worklog(request, attrs), to: WorklogCreate, as: :create

  @doc """
  Reads the full Tempo periods that intersect the range from `:from` to
  `:to`, both inclusive. See `Jido.Connect.Tempo.Client.Periods.list/2`.
  """
  defdelegate list_periods(request, opts), to: Periods, as: :list

  @doc """
  Reads the request account's timesheet approval of the one period from
  `from` to `to`. See `Jido.Connect.Tempo.Client.TimesheetApprovals.get/3`.
  """
  defdelegate get_timesheet_approval(request, from, to), to: TimesheetApprovals, as: :get

  @doc """
  Reads every work attribute of the site. See
  `Jido.Connect.Tempo.Client.WorkAttributes.list/2`.
  """
  defdelegate list_work_attributes(request, opts \\ []), to: WorkAttributes, as: :list

  @doc """
  Reads the account candidates of the Jira project `project_id` with
  their link evidence. See
  `Jido.Connect.Tempo.Client.Accounts.list_for_project/3`.
  """
  defdelegate list_accounts_for_project(request, project_id, opts \\ []),
    to: Accounts,
    as: :list_for_project
end
