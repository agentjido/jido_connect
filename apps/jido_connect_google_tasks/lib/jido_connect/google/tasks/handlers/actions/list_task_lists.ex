defmodule Jido.Connect.Google.Tasks.Handlers.Actions.ListTaskLists do
  @moduledoc false

  alias Jido.Connect.Google.Tasks.Handlers.Actions.Helpers

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- Helpers.fetch_client(credentials),
         {:ok, result} <-
           client.list_task_lists(
             normalize_input(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         task_lists: Enum.map(Map.get(result, :task_lists, []), &Helpers.public_map/1),
         next_page_token: Map.get(result, :next_page_token)
       }
       |> Enum.reject(fn {_key, value} -> is_nil(value) end)
       |> Map.new()}
    end
  end

  defp normalize_input(input), do: Map.put_new(input, :page_size, 20)
end
