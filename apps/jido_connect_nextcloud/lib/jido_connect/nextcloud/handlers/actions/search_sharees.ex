defmodule Jido.Connect.Nextcloud.Handlers.Actions.SearchSharees do
  @moduledoc false

  alias Jido.Connect.Nextcloud.Client.OCS
  alias Jido.Connect.Nextcloud.Handlers.Actions.Helpers
  alias Jido.Connect.Nextcloud.Normalizer

  def run(input, runtime) do
    with {:ok, credentials} <- Helpers.credentials(runtime),
         {:ok, sharees} <-
           OCS.search_sharees(credentials, params(input))
           |> Helpers.handle_ocs_response(
             &Normalizer.sharees/1,
             "Failed to search Nextcloud sharees"
           ) do
      {:ok, %{sharees: Helpers.public_map(sharees)}}
    end
  end

  defp params(input) do
    %{
      search: Map.fetch!(input, :search),
      itemType: Map.get(input, :item_type, "file"),
      perPage: Map.get(input, :per_page, 25),
      lookup: Map.get(input, :lookup, false)
    }
  end
end
