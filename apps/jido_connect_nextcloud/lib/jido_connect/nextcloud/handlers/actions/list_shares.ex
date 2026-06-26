defmodule Jido.Connect.Nextcloud.Handlers.Actions.ListShares do
  @moduledoc false

  alias Jido.Connect.Nextcloud.Client.OCS
  alias Jido.Connect.Nextcloud.Handlers.Actions.Helpers
  alias Jido.Connect.Nextcloud.Normalizer

  def run(input, runtime) do
    with {:ok, credentials} <- Helpers.credentials(runtime),
         {:ok, shares} <-
           OCS.list_shares(credentials, params(input))
           |> Helpers.handle_ocs_response(&Normalizer.shares/1, "Failed to list Nextcloud shares") do
      {:ok, %{shares: Helpers.public_map(shares)}}
    end
  end

  defp params(input) do
    %{
      path: Map.get(input, :path),
      reshares: Map.get(input, :reshares),
      subfiles: Map.get(input, :subfiles)
    }
  end
end
