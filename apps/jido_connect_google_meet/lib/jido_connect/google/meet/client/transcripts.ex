defmodule Jido.Connect.Google.Meet.Client.Transcripts do
  @moduledoc "Google Meet transcripts API boundary."

  alias Jido.Connect.Google.Meet.Client.{Params, Response, Transport}

  def list_transcripts(%{conference_record_name: conference_record_name} = params, access_token)
      when is_binary(conference_record_name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v2/#{encode_resource_name(conference_record_name)}/transcripts",
      params: Params.artifact_list_params(params)
    )
    |> Response.handle_transcript_list_response()
  end

  def get_transcript(%{transcript_name: transcript_name} = params, access_token)
      when is_binary(transcript_name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v2/#{encode_resource_name(transcript_name)}",
      params: Params.fields_params(params)
    )
    |> Response.handle_transcript_response()
  end

  defp encode_resource_name(name) do
    name
    |> String.split("/")
    |> Enum.map(fn segment -> URI.encode(segment, &URI.char_unreserved?/1) end)
    |> Enum.join("/")
  end
end
