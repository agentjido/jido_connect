defmodule Jido.Connect.Google.Calendar.Handlers.Actions.GetAcl do
  @moduledoc false

  alias Jido.Connect.Google.Calendar.Handlers.Actions.{AclResource, ResourceHelpers}

  def run(input, %{credentials: credentials}) do
    with :ok <- AclResource.validate_read(input, [:calendar_id, :acl_rule_id]),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, acl_rule} <-
           client.get_acl(
             AclResource.normalize_input(input),
             Map.get(credentials, :access_token)
           ) do
      {:ok, %{acl_rule: ResourceHelpers.public_map(acl_rule)}}
    end
  end
end
