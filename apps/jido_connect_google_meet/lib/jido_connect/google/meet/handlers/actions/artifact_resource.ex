defmodule Jido.Connect.Google.Meet.Handlers.Actions.ArtifactResource do
  @moduledoc false

  alias Jido.Connect.Google.Meet.Handlers.Actions.ResourceHelpers

  @reason :invalid_artifact_request

  def validate_required(input, fields) do
    Enum.reduce_while(fields, :ok, fn field, :ok ->
      case ResourceHelpers.require_present(input, field, @reason) do
        :ok -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  def normalize_input(input, defaults \\ %{}) do
    ResourceHelpers.normalize_input(input, defaults, [
      :conference_record_name,
      :recording_name,
      :transcript_name,
      :page_token,
      :fields
    ])
  end
end
