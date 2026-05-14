defmodule Jido.Connect.Google.Calendar.Handlers.Actions.ListEventInstances do
  @moduledoc false

  alias Jido.Connect.Google.Calendar.Handlers.Actions.{EventUtilities, ResourceHelpers}

  def run(input, %{credentials: credentials}) do
    with :ok <- EventUtilities.validate_instances(input),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, result} <-
           client.list_event_instances(
             EventUtilities.normalize_input(input, %{page_size: 250, show_deleted: false}),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         events: Enum.map(Map.get(result, :events, []), &ResourceHelpers.public_map/1),
         next_page_token: Map.get(result, :next_page_token),
         next_sync_token: Map.get(result, :next_sync_token)
       }
       |> Enum.reject(fn {_key, value} -> is_nil(value) end)
       |> Map.new()}
    end
  end
end
