defmodule Jido.Connect.Google.Tasks.Handlers.Actions.GetTaskList do
  @moduledoc false

  alias Jido.Connect.Google.Tasks.Handlers.Actions.Helpers

  @reason :invalid_task_list_request

  def run(input, %{credentials: credentials}) do
    input = Helpers.normalize_strings(input, [:task_list_id])

    with :ok <- Helpers.require_present(input, :task_list_id, @reason),
         {:ok, client} <- Helpers.fetch_client(credentials),
         {:ok, task_list} <-
           client.get_task_list(input, Map.get(credentials, :access_token)) do
      {:ok, %{task_list: Helpers.public_map(task_list)}}
    end
  end
end
