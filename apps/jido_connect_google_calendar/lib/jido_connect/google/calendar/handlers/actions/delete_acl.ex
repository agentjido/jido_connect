defmodule Jido.Connect.Google.Calendar.Handlers.Actions.DeleteAcl do
  @moduledoc false

  alias Jido.Connect.Google.Calendar.Handlers.Actions.{AclResource, ResourceHelpers}

  def run(input, %{credentials: credentials}) do
    with :ok <- AclResource.validate_read(input, [:calendar_id, :acl_rule_id]),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, result} <-
           client.delete_acl(
             AclResource.normalize_input(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{result: ResourceHelpers.public_map(result)}}
    end
  end
end
