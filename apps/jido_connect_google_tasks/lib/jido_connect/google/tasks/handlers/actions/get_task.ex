defmodule Jido.Connect.Google.Tasks.Handlers.Actions.GetTask do
  @moduledoc false

  alias Jido.Connect.Google.Tasks.Handlers.Actions.Helpers

  @reason :invalid_task_request

  def run(input, %{credentials: credentials}) do
    input = Helpers.normalize_strings(input, [:task_list_id, :task_id])

    with :ok <- Helpers.require_present(input, :task_list_id, @reason),
         :ok <- Helpers.require_present(input, :task_id, @reason),
         {:ok, client} <- Helpers.fetch_client(credentials),
         {:ok, task} <-
           client.get_task(input, Map.get(credentials, :access_token)) do
      {:ok, %{task: Helpers.public_map(task)}}
    end
  end
end
