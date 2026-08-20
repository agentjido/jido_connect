defmodule Jido.Connect.Jira.Handlers.Actions.ListPlans do
  @moduledoc false
  alias Jido.Connect.Jira.Handlers.Actions.Support

  def run(input, runtime) do
    opts =
      [
        include_archived: Map.get(input, :include_archived, false),
        include_trashed: Map.get(input, :include_trashed, false),
        limit: Map.get(input, :limit, 50),
        cursor: Map.get(input, :cursor)
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    Support.call(runtime, & &1.list_plans(&2, opts))
  end
end

defmodule Jido.Connect.Jira.Handlers.Actions.GetPlan do
  @moduledoc false
  alias Jido.Connect.Jira.Handlers.Actions.Support
  def run(input, runtime), do: Support.call(runtime, & &1.get_plan(input.id, &2))
end

defmodule Jido.Connect.Jira.Handlers.Actions.CreatePlan do
  @moduledoc false
  alias Jido.Connect.Jira.Handlers.Actions.Support
  alias Jido.Connect.Jira.Input.Plans

  def run(input, runtime) do
    with {:ok, attrs} <- Plans.create(input) do
      Support.call(runtime, & &1.create_plan(attrs, &2))
    end
  end
end

defmodule Jido.Connect.Jira.Handlers.Actions.UpdatePlan do
  @moduledoc false
  alias Jido.Connect.Jira.Handlers.Actions.Support
  alias Jido.Connect.Jira.Input.Plans

  def run(input, runtime) do
    with {:ok, input} <- Plans.update(input) do
      attrs = Map.drop(input, [:id])
      Support.call(runtime, & &1.update_plan(input.id, attrs, &2))
    end
  end
end

defmodule Jido.Connect.Jira.Handlers.Actions.DuplicatePlan do
  @moduledoc false
  alias Jido.Connect.Jira.Handlers.Actions.Support

  def run(input, runtime),
    do: Support.call(runtime, & &1.duplicate_plan(input.id, input.name, &2))
end

defmodule Jido.Connect.Jira.Handlers.Actions.ArchivePlan do
  @moduledoc false
  alias Jido.Connect.Jira.Handlers.Actions.Support
  def run(input, runtime), do: Support.call(runtime, & &1.archive_plan(input.id, &2))
end

defmodule Jido.Connect.Jira.Handlers.Actions.TrashPlan do
  @moduledoc false
  alias Jido.Connect.Jira.Handlers.Actions.Support
  def run(input, runtime), do: Support.call(runtime, & &1.trash_plan(input.id, &2))
end
