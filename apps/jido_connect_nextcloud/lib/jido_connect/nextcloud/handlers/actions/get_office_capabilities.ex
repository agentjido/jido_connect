defmodule Jido.Connect.Nextcloud.Handlers.Actions.GetOfficeCapabilities do
  @moduledoc false

  alias Jido.Connect.Nextcloud.Client.OCS
  alias Jido.Connect.Nextcloud.Handlers.Actions.Helpers
  alias Jido.Connect.Nextcloud.Normalizer

  def run(_input, runtime) do
    with {:ok, credentials} <- Helpers.credentials(runtime),
         {:ok, capabilities} <-
           OCS.capabilities(credentials)
           |> Helpers.handle_ocs_response(&{:ok, &1}, "Failed to fetch Nextcloud capabilities") do
      {:ok,
       %{
         capabilities: capabilities,
         office: Normalizer.office_capabilities(capabilities)
       }}
    end
  end
end
