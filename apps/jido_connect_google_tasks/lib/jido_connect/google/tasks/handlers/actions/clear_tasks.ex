defmodule Jido.Connect.Google.Tasks.Handlers.Actions.ClearTasks do
  @moduledoc false

  alias Jido.Connect.Google.Tasks.Handlers.Actions.Helpers

  @reason :invalid_task_request

  def run(input, %{credentials: credentials}) do
    input = Helpers.normalize_strings(input, [:task_list_id])

    with :ok <- Helpers.require_present(input, :task_list_id, @reason),
         {:ok, client} <- Helpers.fetch_client(credentials),
         {:ok, result} <-
           client.clear_tasks(input, Map.get(credentials, :access_token)) do
      {:ok, %{result: Helpers.public_map(result)}}
    end
  end
end
