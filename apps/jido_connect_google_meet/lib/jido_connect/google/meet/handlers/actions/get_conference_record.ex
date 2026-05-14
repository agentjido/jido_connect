defmodule Jido.Connect.Google.Meet.Handlers.Actions.GetConferenceRecord do
  @moduledoc false

  alias Jido.Connect.Google.Meet.Handlers.Actions.{ConferenceRecordResource, ResourceHelpers}

  def run(input, %{credentials: credentials}) do
    with :ok <- ConferenceRecordResource.validate_required(input, [:conference_record_name]),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, conference_record} <-
           client.get_conference_record(
             ConferenceRecordResource.normalize_input(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{conference_record: ResourceHelpers.public_map(conference_record)}}
    end
  end
end
