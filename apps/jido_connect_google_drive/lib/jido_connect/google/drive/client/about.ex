defmodule Jido.Connect.Google.Drive.Client.About do
  @moduledoc "Google Drive about API boundary."

  alias Jido.Connect.Google.Drive.Client.{Params, Response, Transport}

  def get_about(params, access_token) when is_map(params) and is_binary(access_token) do
    access_token
    |> Transport.request()
    |> Req.get(url: "/v3/about", params: Params.about_params(params))
    |> Response.handle_about_response()
  end
end
