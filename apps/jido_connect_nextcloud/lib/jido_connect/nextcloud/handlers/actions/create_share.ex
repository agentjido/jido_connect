defmodule Jido.Connect.Nextcloud.Handlers.Actions.CreateShare do
  @moduledoc false

  alias Jido.Connect.Nextcloud.Client.OCS
  alias Jido.Connect.Nextcloud.Handlers.Actions.Helpers
  alias Jido.Connect.Nextcloud.Normalizer

  def run(input, runtime) do
    with {:ok, credentials} <- Helpers.credentials(runtime),
         {:ok, share} <-
           OCS.create_share(credentials, share_params(input))
           |> Helpers.handle_ocs_response(&Normalizer.share/1, "Failed to create Nextcloud share") do
      {:ok, %{share: Helpers.public_map(share)}}
    end
  end

  defp share_params(input) do
    %{
      path: Map.fetch!(input, :path),
      shareType: Map.fetch!(input, :share_type),
      shareWith: Map.get(input, :share_with),
      permissions: Map.get(input, :permissions, 1),
      password: Map.get(input, :password),
      expireDate: Map.get(input, :expire_date),
      note: Map.get(input, :note),
      label: Map.get(input, :label),
      publicUpload: Map.get(input, :public_upload, false),
      sendMail: Map.get(input, :send_mail, false)
    }
  end
end
