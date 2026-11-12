defmodule Jido.Connect.Google.Meet.Handlers.Actions.GetParticipant do
  @moduledoc false

  alias Jido.Connect.Google.Meet.Handlers.Actions.{ConferenceRecordResource, ResourceHelpers}

  def run(input, %{credentials: credentials}) do
    with :ok <- ConferenceRecordResource.validate_required(input, [:participant_name]),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, participant} <-
           client.get_participant(
             ConferenceRecordResource.normalize_input(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{participant: ResourceHelpers.public_map(participant)}}
    end
  end
end
