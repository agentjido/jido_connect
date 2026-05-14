defmodule Jido.Connect.Google.Meet.Handlers.Actions.GetRecording do
  @moduledoc false

  alias Jido.Connect.Google.Meet.Handlers.Actions.{ArtifactResource, ResourceHelpers}

  def run(input, %{credentials: credentials}) do
    with :ok <- ArtifactResource.validate_required(input, [:recording_name]),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, recording} <-
           client.get_recording(
             ArtifactResource.normalize_input(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{recording: ResourceHelpers.public_map(recording)}}
    end
  end
end
