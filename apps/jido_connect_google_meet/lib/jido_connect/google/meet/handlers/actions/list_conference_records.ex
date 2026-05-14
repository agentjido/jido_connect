defmodule Jido.Connect.Google.Meet.Handlers.Actions.ListConferenceRecords do
  @moduledoc false

  alias Jido.Connect.Google.Meet.Handlers.Actions.{ConferenceRecordResource, ResourceHelpers}

  def run(input, %{credentials: credentials}) do
    with {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, result} <-
           client.list_conference_records(
             ConferenceRecordResource.normalize_input(input, %{page_size: 25}),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         conference_records:
           Enum.map(Map.get(result, :conference_records, []), &ResourceHelpers.public_map/1),
         next_page_token: Map.get(result, :next_page_token)
       }
       |> Enum.reject(fn {_key, value} -> is_nil(value) end)
       |> Map.new()}
    end
  end
end
