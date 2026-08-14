defmodule Jido.Connect.Nextcloud.Handlers.Actions.GetShare do
  @moduledoc false

  alias Jido.Connect.Nextcloud.Client.OCS
  alias Jido.Connect.Nextcloud.Handlers.Actions.Helpers
  alias Jido.Connect.Nextcloud.Normalizer

  def run(input, runtime) do
    with {:ok, credentials} <- Helpers.credentials(runtime),
         {:ok, share} <-
           OCS.get_share(credentials, Map.fetch!(input, :share_id))
           |> Helpers.handle_ocs_response(&Normalizer.share/1, "Failed to get Nextcloud share") do
      {:ok, %{share: Helpers.public_map(share)}}
    end
  end
end
