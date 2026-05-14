defmodule Jido.Connect.Google.Meet.Handlers.Actions.GetTranscript do
  @moduledoc false

  alias Jido.Connect.Google.Meet.Handlers.Actions.{ArtifactResource, ResourceHelpers}

  def run(input, %{credentials: credentials}) do
    with :ok <- ArtifactResource.validate_required(input, [:transcript_name]),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, transcript} <-
           client.get_transcript(
             ArtifactResource.normalize_input(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{transcript: ResourceHelpers.public_map(transcript)}}
    end
  end
end
