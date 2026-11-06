defmodule Jido.Connect.Google.Meet.Handlers.Actions.ListParticipants do
  @moduledoc false

  alias Jido.Connect.Google.Meet.Handlers.Actions.{ConferenceRecordResource, ResourceHelpers}

  def run(input, %{credentials: credentials}) do
    with :ok <- ConferenceRecordResource.validate_required(input, [:conference_record_name]),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, result} <-
           client.list_participants(
             ConferenceRecordResource.normalize_input(input, %{page_size: 10}),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         participants:
           Enum.map(Map.get(result, :participants, []), &ResourceHelpers.public_map/1),
         next_page_token: Map.get(result, :next_page_token)
       }
       |> Enum.reject(fn {_key, value} -> is_nil(value) end)
       |> Map.new()}
    end
  end
end
