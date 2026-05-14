defmodule Jido.Connect.Google.Calendar.Handlers.Actions.PatchCalendarListEntry do
  @moduledoc false

  alias Jido.Connect.Google.Calendar.Handlers.Actions.{CalendarResource, ResourceHelpers}

  def run(input, %{credentials: credentials}) do
    with :ok <- CalendarResource.validate_required(input, [:calendar_id]),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, calendar} <-
           client.patch_calendar_list_entry(
             CalendarResource.normalize_input(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{calendar: ResourceHelpers.public_map(calendar)}}
    end
  end
end
