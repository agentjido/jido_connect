defmodule Jido.Connect.Jira.Handlers.Actions.ListFilters do
  @moduledoc false
  alias Jido.Connect.Jira.Handlers.Actions.Support

  def run(input, runtime) do
    opts =
      [
        name: Map.get(input, :name),
        owner_account_id: Map.get(input, :owner_account_id),
        limit: Map.get(input, :limit, 50),
        offset: Map.get(input, :offset, 0)
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    Support.call(runtime, & &1.list_filters(&2, opts))
  end
end

defmodule Jido.Connect.Jira.Handlers.Actions.GetFilter do
  @moduledoc false
  alias Jido.Connect.Jira.Handlers.Actions.Support
  def run(input, runtime), do: Support.call(runtime, & &1.get_filter(input.id, &2))
end

defmodule Jido.Connect.Jira.Handlers.Actions.CreateFilter do
  @moduledoc false
  alias Jido.Connect.Jira.Handlers.Actions.Support

  def run(input, runtime) do
    attrs = Map.take(input, [:name, :query, :description, :favorite])
    Support.call(runtime, & &1.create_filter(attrs, &2))
  end
end

defmodule Jido.Connect.Jira.Handlers.Actions.UpdateFilter do
  @moduledoc false
  alias Jido.Connect.Jira.Handlers.Actions.Support

  def run(input, runtime) do
    attrs = Map.take(input, [:name, :query, :description, :favorite])
    Support.call(runtime, & &1.update_filter(input.id, attrs, &2))
  end
end

defmodule Jido.Connect.Jira.Handlers.Actions.GetFilterColumns do
  @moduledoc false
  alias Jido.Connect.Jira.Handlers.Actions.Support
  def run(input, runtime), do: Support.call(runtime, & &1.get_filter_columns(input.id, &2))
end

defmodule Jido.Connect.Jira.Handlers.Actions.UpdateFilterColumns do
  @moduledoc false
  alias Jido.Connect.Jira.Handlers.Actions.Support
  alias Jido.Connect.Jira.Input.Filters

  def run(input, runtime) do
    with {:ok, input} <- Filters.columns(input) do
      Support.call(runtime, & &1.update_filter_columns(input.id, input.columns, &2))
    end
  end
end

defmodule Jido.Connect.Jira.Handlers.Actions.UpdateFilterShare do
  @moduledoc false
  alias Jido.Connect.Jira.Handlers.Actions.Support
  alias Jido.Connect.Jira.Input.Filters

  def run(input, runtime) do
    with {:ok, input} <- Filters.share(input) do
      attrs = Map.take(input, [:scope, :projects, :group_ids])
      Support.call(runtime, & &1.replace_filter_shares(input.id, attrs, &2))
    end
  end
end
