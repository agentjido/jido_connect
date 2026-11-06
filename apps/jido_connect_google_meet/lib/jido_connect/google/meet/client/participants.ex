defmodule Jido.Connect.Google.Meet.Client.Participants do
  @moduledoc "Google Meet conference participants API boundary."

  alias Jido.Connect.Google.Meet.Client.{Params, Response, Transport}

  def list_participants(%{conference_record_name: conference_record_name} = params, access_token)
      when is_binary(conference_record_name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v2/#{encode_resource_name(conference_record_name)}/participants",
      params: Params.artifact_list_params(params)
    )
    |> Response.handle_participant_list_response()
  end

  def get_participant(%{participant_name: participant_name} = params, access_token)
      when is_binary(participant_name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v2/#{encode_resource_name(participant_name)}",
      params: Params.fields_params(params)
    )
    |> Response.handle_participant_response()
  end

  defp encode_resource_name(name) do
    name
    |> String.split("/")
    |> Enum.map(fn segment -> URI.encode(segment, &URI.char_unreserved?/1) end)
    |> Enum.join("/")
  end
end
