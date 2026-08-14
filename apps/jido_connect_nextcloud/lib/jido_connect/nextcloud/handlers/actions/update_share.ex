defmodule Jido.Connect.Nextcloud.Handlers.Actions.UpdateShare do
  @moduledoc false

  alias Jido.Connect.Nextcloud.Client.OCS
  alias Jido.Connect.Nextcloud.Handlers.Actions.Helpers
  alias Jido.Connect.Nextcloud.Normalizer

  def run(input, runtime) do
    share_id = Map.fetch!(input, :share_id)

    with {:ok, credentials} <- Helpers.credentials(runtime),
         {:ok, share} <-
           OCS.update_share(credentials, share_id, update_params(input))
           |> Helpers.handle_ocs_response(&Normalizer.share/1, "Failed to update Nextcloud share") do
      {:ok, %{share: Helpers.public_map(share)}}
    end
  end

  defp update_params(input) do
    %{
      permissions: Map.get(input, :permissions),
      password: Map.get(input, :password),
      expireDate: Map.get(input, :expire_date),
      note: Map.get(input, :note),
      label: Map.get(input, :label),
      publicUpload: Map.get(input, :public_upload),
      sendMail: Map.get(input, :send_mail)
    }
  end
end
