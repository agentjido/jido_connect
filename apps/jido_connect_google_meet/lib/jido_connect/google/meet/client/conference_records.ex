defmodule Jido.Connect.Google.Meet.Client.ConferenceRecords do
  @moduledoc "Google Meet conference records API boundary."

  alias Jido.Connect.Google.Meet.Client.{Params, Response, Transport}

  def list_conference_records(params, access_token)
      when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v2/conferenceRecords",
      params: Params.conference_record_list_params(params)
    )
    |> Response.handle_conference_record_list_response()
  end

  def get_conference_record(
        %{conference_record_name: conference_record_name} = params,
        access_token
      )
      when is_binary(conference_record_name) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(
      url: "/v2/#{encode_resource_name(conference_record_name)}",
      params: Params.fields_params(params)
    )
    |> Response.handle_conference_record_response()
  end

  defp encode_resource_name(name) do
    name
    |> String.split("/")
    |> Enum.map(fn segment -> URI.encode(segment, &URI.char_unreserved?/1) end)
    |> Enum.join("/")
  end
end
