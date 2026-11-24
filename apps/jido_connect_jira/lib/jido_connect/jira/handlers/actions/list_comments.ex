defmodule Jido.Connect.Jira.Handlers.Actions.ListComments do
  @moduledoc false

  alias Jido.Connect.Jira.Handlers.Actions.Support

  def run(input, runtime) do
    opts = input |> Map.take([:start_at, :max_results]) |> Enum.to_list()
    Support.call(runtime, & &1.list_comments(input.issue_key, &2, opts))
  end
end
