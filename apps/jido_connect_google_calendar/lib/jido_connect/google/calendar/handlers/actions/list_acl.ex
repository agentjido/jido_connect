defmodule Jido.Connect.Google.Calendar.Handlers.Actions.ListAcl do
  @moduledoc false

  alias Jido.Connect.Google.Calendar.Handlers.Actions.{AclResource, ResourceHelpers}

  def run(input, %{credentials: credentials}) do
    with :ok <- AclResource.validate_read(input, [:calendar_id]),
         {:ok, client} <- ResourceHelpers.fetch_client(credentials),
         {:ok, result} <-
           client.list_acl(
             AclResource.normalize_input(input, %{page_size: 100, show_deleted: false}),
             Map.get(credentials, :access_token)
           ) do
      {:ok,
       %{
         acl_rules: Enum.map(Map.get(result, :acl_rules, []), &ResourceHelpers.public_map/1),
         next_page_token: Map.get(result, :next_page_token),
         next_sync_token: Map.get(result, :next_sync_token)
       }
       |> Enum.reject(fn {_key, value} -> is_nil(value) end)
       |> Map.new()}
    end
  end
end
