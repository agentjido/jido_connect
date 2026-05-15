defmodule Jido.Connect.Google.Tasks.Client do
  @moduledoc """
  Google Tasks API client facade.

  Delegates to capability-oriented submodules for each Tasks resource.
  """

  alias Jido.Connect.Google.Tasks.Client.{TaskLists, Tasks}

  defdelegate list_task_lists(params, access_token), to: TaskLists
  defdelegate get_task_list(params, access_token), to: TaskLists
  defdelegate create_task_list(params, access_token), to: TaskLists
  defdelegate update_task_list(params, access_token), to: TaskLists
  defdelegate delete_task_list(params, access_token), to: TaskLists

  defdelegate list_tasks(params, access_token), to: Tasks
  defdelegate get_task(params, access_token), to: Tasks
  defdelegate create_task(params, access_token), to: Tasks
  defdelegate update_task(params, access_token), to: Tasks
  defdelegate delete_task(params, access_token), to: Tasks
  defdelegate clear_tasks(params, access_token), to: Tasks
  defdelegate move_task(params, access_token), to: Tasks
end
