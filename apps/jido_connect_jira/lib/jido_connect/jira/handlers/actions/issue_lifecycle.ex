defmodule Jido.Connect.Jira.Handlers.Actions.ListIssueTransitions do
  @moduledoc false
  alias Jido.Connect.Jira.Handlers.Actions.Support

  def run(input, runtime),
    do: Support.call(runtime, & &1.list_issue_transitions(input.issue_key, &2))
end

defmodule Jido.Connect.Jira.Handlers.Actions.DeleteIssue do
  @moduledoc false
  alias Jido.Connect.Jira.Handlers.Actions.Support
  def run(input, runtime), do: Support.call(runtime, & &1.delete_issue(input.issue_key, &2))
end
