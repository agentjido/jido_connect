defmodule Jido.Connect.Nextcloud.Handlers.Actions.DeleteShare do
  @moduledoc false

  alias Jido.Connect.Nextcloud.Client.{OCS, Transport}
  alias Jido.Connect.Nextcloud.Handlers.Actions.Helpers

  def run(input, runtime) do
    share_id = Map.fetch!(input, :share_id)

    with {:ok, credentials} <- Helpers.credentials(runtime) do
      case OCS.delete_share(credentials, share_id) do
        {:ok, %{status: status}} when status in 200..299 ->
          {:ok, %{deleted: true, share_id: share_id}}

        other ->
          Transport.handle_error_response(other, message: "Failed to delete Nextcloud share")
      end
    end
  end
end
