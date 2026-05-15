defmodule Jido.Connect.Google.Tasks.Handlers.Actions.ListTasks do
  @moduledoc false

  alias Jido.Connect.Google.Tasks.Handlers.Actions.Helpers

  def run(input, %{credentials: credentials}) do
    input = Helpers.normalize_strings(input, [:task_list_id])

    with :ok <- Helpers.require_present(input, :task_list_id, :invalid_task_request),
         {:ok, client} <- Helpers.fetch_client(credentials),
         {:ok, result} <-
           client.list_tasks(
             normalize_input(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         tasks: Enum.map(Map.get(result, :tasks, []), &Helpers.public_map/1),
         next_page_token: Map.get(result, :next_page_token)
       }
       |> Enum.reject(fn {_key, value} -> is_nil(value) end)
       |> Map.new()}
    end
  end

  defp normalize_input(input), do: Map.put_new(input, :page_size, 20)
end
