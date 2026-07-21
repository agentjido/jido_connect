defmodule Jido.Connect.Nextcloud.Handlers.Actions.GetOfficeLaunchToken do
  @moduledoc false

  alias Jido.Connect.Nextcloud.Client.OCS
  alias Jido.Connect.Nextcloud.Handlers.Actions.Helpers
  alias Jido.Connect.Nextcloud.Normalizer

  def run(input, runtime) do
    with {:ok, credentials} <- Helpers.credentials(runtime),
         {:ok, launch} <-
           OCS.office_launch_token(
             credentials,
             Map.fetch!(input, :file_id),
             Map.fetch!(input, :app_id),
             Map.fetch!(input, :app_secret)
           )
           |> Helpers.handle_ocs_response(
             &Normalizer.office_launch/1,
             "Failed to fetch Office launch token"
           ) do
      {:ok, %{launch: launch}}
    end
  end
end
