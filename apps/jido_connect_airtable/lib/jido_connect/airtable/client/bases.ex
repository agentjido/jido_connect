defmodule Jido.Connect.Airtable.Client.Bases do
  @moduledoc false

  alias Jido.Connect.Airtable.Client.{Response, Transport}

  @doc "Lists all accessible Airtable bases."
  def list_bases(params, access_token) do
    Transport.api_request(access_token)
    |> Req.merge(url: "/v0/meta/bases", params: Map.take(params, [:offset]))
    |> Req.get()
    |> Response.handle_list_bases_response()
  end

  @doc "Gets the schema for a specific Airtable base."
  def get_base(params, access_token) do
    base_id = Map.fetch!(params, :base_id)

    Transport.api_request(access_token)
    |> Req.merge(url: "/v0/meta/bases/#{base_id}")
    |> Req.get()
    |> Response.handle_get_base_response()
  end
end
