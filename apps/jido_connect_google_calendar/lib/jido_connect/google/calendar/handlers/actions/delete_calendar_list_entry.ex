defmodule Jido.Connect.Google.Calendar.Handlers.Actions.DeleteCalendarListEntry do
  @moduledoc false

  alias Jido.Connect.Google.Calendar.Handlers.Actions.{CalendarResource, ResourceHelpers}

  def run(input, %{credentials: credentials}) do
    with :ok <- CalendarResource.validate_required(input, [:calendar_id]),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, result} <-
           client.delete_calendar_list_entry(
             CalendarResource.normalize_input(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{result: ResourceHelpers.public_map(result)}}
    end
  end
end
