defmodule Jido.Connect.MicrosoftSharepoint.Client.DocumentLibraries do
  @moduledoc false

  alias Jido.Connect.Microsoft.Transport
  alias Jido.Connect.MicrosoftOnedrive.Normalizer
  alias Jido.Connect.MicrosoftSharepoint.{GraphPath, Query}
  alias Jido.Connect.MicrosoftSharepoint.Client.Response

  def list(access_token, input) do
    with {:ok, url} <- GraphPath.resource_path(["sites", Map.get(input, :site_id), "drives"]) do
      access_token
      |> Transport.request()
      |> Transport.request(:get, url: url, params: Query.page(input))
      |> Response.page(&Normalizer.drive/1, :libraries, "Failed to list SharePoint libraries")
    end
  end
end
