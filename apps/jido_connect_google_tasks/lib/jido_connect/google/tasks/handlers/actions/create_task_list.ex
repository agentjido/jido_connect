defmodule Jido.Connect.Google.Tasks.Handlers.Actions.CreateTaskList do
  @moduledoc false

  alias Jido.Connect.Google.Tasks.Handlers.Actions.Helpers

  @reason :invalid_task_list_request

  def run(input, %{credentials: credentials}) do
    input = Helpers.normalize_strings(input, [:title])

    with :ok <- Helpers.require_present(input, :title, @reason),
         {:ok, client} <- Helpers.fetch_client(credentials),
         {:ok, task_list} <-
           client.create_task_list(input, Map.get(credentials, :access_token)) do
      {:ok, %{task_list: Helpers.public_map(task_list)}}
    end
  end
end
