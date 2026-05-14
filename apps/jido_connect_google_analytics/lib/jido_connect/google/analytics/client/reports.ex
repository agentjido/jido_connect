defmodule Jido.Connect.Google.Analytics.Client.Reports do
  @moduledoc "Google Analytics report API boundary."

  alias Jido.Connect.Google.Analytics.Client.{Response, Transport}

  def run_report(%{property: property, body: body}, access_token)
      when is_binary(property) and is_map(body) and is_binary(access_token) do
    access_token
    |> Transport.data_request()
    |> Req.post(
      url: "/v1beta/#{encode_resource_name(property)}:runReport",
      json: body
    )
    |> Response.handle_report_response()
  end

  def batch_run_reports(%{property: property, body: body}, access_token)
      when is_binary(property) and is_map(body) and is_binary(access_token) do
    access_token
    |> Transport.data_request()
    |> Req.post(
      url: "/v1beta/#{encode_resource_name(property)}:batchRunReports",
      json: body
    )
    |> Response.handle_batch_report_response()
  end

  defp encode_resource_name(name) do
    name
    |> String.split("/")
    |> Enum.map(fn segment -> URI.encode(segment, &URI.char_unreserved?/1) end)
    |> Enum.join("/")
  end
end
